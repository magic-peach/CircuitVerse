# frozen_string_literal: true

class LtiController < ApplicationController
  DEPLOYMENT_ID_CLAIM = Lti::Claims::DEPLOYMENT_ID

  LTI_STATE_PURPOSE = "lti.launch.state"
  LTI_STATE_TTL = 5.minutes

  before_action :ensure_lti_enabled, only: %i[launch oidc_login jwks tool_config]
  before_action :require_lti_advantage_feature, only: %i[oidc_login jwks tool_config]
  before_action :set_group_and_assignment, only: %i[launch]
  before_action :set_lti_params, only: %i[launch]
  after_action :allow_iframe_lti, only: %i[launch]
  skip_before_action :authenticate_user!, only: %i[launch oidc_login jwks tool_config],
                                          raise: false

  def launch
    if params[:id_token].present?
      return lti_advantage_unavailable unless lti_advantage_enabled?

      handle_lti_13_launch
    else
      handle_lti_11_launch
    end
  end

  def oidc_login
    deployment = find_login_deployment

    nonce = SecureRandom.hex(16)
    state = lti_state_verifier.generate(
      { "nonce" => nonce, "deployment_id" => deployment.id },
      purpose: LTI_STATE_PURPOSE,
      expires_in: LTI_STATE_TTL
    )

    redirect_to build_oidc_redirect(deployment, nonce, state),
                allow_other_host: true
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Unknown LTI platform" }, status: :not_found
  end

  def jwks
    render json: { keys: [Lti::KeyManager.jwk] }
  end

  def tool_config
    render json: {
      title: "CircuitVerse",
      description: "Digital circuit simulator for education",
      target_link_uri: "#{request.base_url}/lti/launch",
      oidc_initiation_url: "#{request.base_url}/lti/login",
      public_jwk_url: "#{request.base_url}/lti/jwks"
    }
  end

  private

    def ensure_lti_enabled
      return if Flipper.enabled?(:lms_integration, current_user)

      render json: { error: "LTI integration is not enabled" }, status: :not_found
    end

    def lti_advantage_enabled?
      Flipper.enabled?(:lti_advantage)
    end

    def require_lti_advantage_feature
      lti_advantage_unavailable unless lti_advantage_enabled?
    end

    def lti_advantage_unavailable
      render json: { error: "LTI 1.3 is not enabled" }, status: :not_found
    end

    def lti_state_verifier
      Rails.application.message_verifier(LTI_STATE_PURPOSE)
    end

    def consume_lti_state(state)
      Rails.cache.write("lti:state:#{Digest::SHA256.hexdigest(state)}",
                        true, unless_exist: true, expires_in: LTI_STATE_TTL)
    end

    def find_login_deployment
      conditions = { issuer: params.expect(:iss) }
      conditions[:client_id] = params[:client_id] if params[:client_id].present?
      LtiDeployment.find_by!(conditions)
    end

    def verified_request?
      super || lti_request_verified_by_protocol?
    end

    def lti_request_verified_by_protocol?
      case action_name
      when "launch"
        (params[:id_token].present? && params[:state].present?) ||
          (params[:oauth_consumer_key].present? && params[:oauth_signature].present?)
      when "oidc_login"
        params[:iss].present? && params[:login_hint].present? &&
          params[:target_link_uri].present?
      else
        false
      end
    end

    def handle_lti_13_launch
      state      = params[:state].to_s
      state_data = lti_state_verifier.verified(state, purpose: LTI_STATE_PURPOSE)
      if state_data.blank?
        render json: { error: "Invalid or expired state" }, status: :unauthorized
        return
      end

      unless consume_lti_state(state)
        render json: { error: "State already used" }, status: :unauthorized
        return
      end

      deployment = find_lti_13_deployment(params[:id_token])
      payload    = Lti::JwtValidator.validate!(
        params[:id_token],
        deployment: deployment,
        nonce: state_data["nonce"]
      )

      session[:is_lti] = true
      route_lti_13_launch(payload, deployment)
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Unknown deployment" }, status: :not_found
    rescue SecurityError, JWT::DecodeError => e
      render json: { error: e.message }, status: :unauthorized
    end

    def route_lti_13_launch(payload, deployment)
      @assignment = resolve_lti_13_assignment(payload, deployment)
      if @assignment.blank?
        flash.now[:notice] = t(".notice_no_assignment")
        render :launch_error, status: :unauthorized
        return
      end

      @group = @assignment.group
      store_lti_13_context(deployment)

      email  = payload["email"]
      @user  = User.find_by(email: email) if email.present?

      if @user.blank?
        flash[:notice] = t(".notice_no_account_in_cv", email_from_lms: email)
        render :launch_error, status: :bad_request
      elsif @user.id == @group.primary_mentor_id
        sign_in(@user)
        redirect_to group_assignment_path(@group, @assignment),
                    notice: t(".notice_lms_auth_success_teacher",
                              email_from_lms: email,
                              lms_type: lti_13_platform_name(payload),
                              course_title_from_lms: lti_13_course_title(payload))
      elsif GroupMember.exists?(user_id: @user.id, group_id: @group.id)
        flash[:notice] = t(".notice_students_open_in_cv")
        create_project_for_lti_13(payload)
        render :open_incv, status: :ok
      else
        flash[:notice] = t(".notice_ask_teacher")
        render :launch_error, status: :unauthorized
      end
    end

    def handle_lti_11_launch
      session[:is_lti] = true
      if @assignment.blank?
        flash.now[:notice] = t(".notice_no_assignment")
        render :launch_error, status: :unauthorized
        return
      end
      require "oauth/request_proxy/action_controller_request"
      @provider = IMS::LTI::ToolProvider.new(
        params[:oauth_consumer_key],
        @assignment.lti_shared_secret,
        params
      )

      unless @provider.valid_request?(request)
        render :launch_error, status: :unauthorized
        return
      end

      @user = User.find_by(email: @email_from_lms)

      if @user.present?
        if @user.id == @group.primary_mentor_id
          sign_in(@user)
          lms_auth_success_notice = t(".notice_lms_auth_success_teacher",
                                      email_from_lms: @email_from_lms,
                                      lms_type: @lms_type,
                                      course_title_from_lms: @course_title_from_lms)
          redirect_to group_assignment_path(@group, @assignment),
                      notice: lms_auth_success_notice
        elsif GroupMember.exists?(user_id: @user.id, group_id: @group.id)
          flash[:notice] = t(".notice_students_open_in_cv")
          create_project_if_student_present
          render :open_incv, status: :ok
        else
          flash[:notice] = t(".notice_ask_teacher")
          render :launch_error, status: :unauthorized
        end
      else
        flash[:notice] = t(".notice_no_account_in_cv",
                           email_from_lms: @email_from_lms)
        render :launch_error, status: :bad_request
      end
    end

    def find_lti_13_deployment(token)
      payload, _header = JWT.decode(token, nil, false)
      LtiDeployment.find_by!(
        issuer: payload["iss"],
        client_id: unverified_client_id(payload),
        deployment_id: payload[DEPLOYMENT_ID_CLAIM]
      )
    end

    def unverified_client_id(payload)
      aud = payload["aud"]
      return aud unless aud.is_a?(Array)

      aud.size > 1 ? payload["azp"] : aud.first
    end

    def resolve_lti_13_assignment(payload, deployment)
      return if deployment.group.blank?

      custom = payload[Lti::Claims::CUSTOM]
      assignment_id = custom.is_a?(Hash) ? custom["assignment_id"] : nil
      return if assignment_id.blank?

      deployment.group.assignments.find_by(id: assignment_id)
    end

    def lti_13_platform_name(payload)
      platform = payload[Lti::Claims::TOOL_PLATFORM]
      return "LMS" unless platform.is_a?(Hash)

      platform["product_family_code"].presence || platform["name"].presence || "LMS"
    end

    def lti_13_course_title(payload)
      context = payload[Lti::Claims::CONTEXT]
      context.is_a?(Hash) ? context["title"] : nil
    end

    def store_lti_13_context(deployment)
      clear_lti_11_grade_context
      session[:lms_domain] = URI.join(deployment.issuer, "/").to_s
    end

    def clear_lti_11_grade_context
      session.delete(:lis_outcome_service_url)
      session.delete(:oauth_consumer_key)
      session.delete(:lti_11_assignment_id)
    end

    def create_project_for_lti_13(payload)
      sub = payload["sub"]
      project = Project.find_by(author_id: @user.id, assignment_id: @assignment.id)

      if project.present?
        project.update(lis_result_sourced_id: sub) if sub.present? && project.lis_result_sourced_id != sub
        return
      end

      project = @user.projects.create(
        name: "#{@user.name}/#{@assignment.name}",
        assignment_id: @assignment.id,
        project_access_type: "Private",
        lis_result_sourced_id: sub
      )
      project.build_project_datum
      project.save
    end

    def set_group_and_assignment
      return if params[:oauth_consumer_key].blank?

      @assignment = Assignment.find_by(
        lti_consumer_key: params[:oauth_consumer_key]
      )
      @group = @assignment.group if @assignment.present?
    end

    def set_lti_params
      clear_lti_11_grade_context
      @email_from_lms        = params[:lis_person_contact_email_primary]
      @lms_type              = params[:tool_consumer_info_product_family_code]
      @course_title_from_lms = params[:context_title]
      lms_domain             = params[:launch_presentation_return_url]
      if @assignment.present? && params[:lis_outcome_service_url].present?
        session[:lis_outcome_service_url] = params[:lis_outcome_service_url]
        session[:oauth_consumer_key]      = params[:oauth_consumer_key]
        session[:lti_11_assignment_id]    = @assignment.id
      end
      session[:lms_domain] = URI.join(lms_domain, "/") if lms_domain
    end

    def create_project_if_student_present
      @user    = User.find_by(email: @email_from_lms)
      @project = Project.find_by(author_id: @user.id,
                                 assignment_id: @assignment.id)
      return if @project.present?

      @project = @user.projects.create(
        name: "#{@user.name}/#{@assignment.name}",
        assignment_id: @assignment.id,
        project_access_type: "Private",
        lis_result_sourced_id: params[:lis_result_sourcedid]
      )
      @project.build_project_datum
      @project.save
    end

    def build_oidc_redirect(deployment, nonce, state)
      uri = URI(deployment.auth_login_url)
      uri.query = URI.encode_www_form(
        response_type: "id_token",
        response_mode: "form_post",
        scope: "openid",
        client_id: deployment.client_id,
        redirect_uri: lti_launch_url,
        login_hint: params[:login_hint],
        lti_message_hint: params[:lti_message_hint],
        nonce: nonce,
        prompt: "none",
        state: state
      )
      uri.to_s
    end

    def allow_iframe_lti
      return unless session[:is_lti]

      response.headers["X-FRAME-OPTIONS"] = "ALLOW-FROM #{session[:lms_domain]}"
    end
end
