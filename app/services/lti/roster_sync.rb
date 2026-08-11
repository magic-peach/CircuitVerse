# frozen_string_literal: true

module Lti
  class RosterSync
    Result = Struct.new(:added, :removed)

    class << self
      def call(group, resource_link)
        deployment = resource_link.lti_deployment
        members = Membership.fetch(resource_link.context_memberships_url, token_for(deployment))

        result = Result.new(RosterImport.call(group, learners(members), deployment),
                            RosterDrop.call(group, members, deployment))
        group.update!(lti_last_synced_at: Time.current)
        result
      end

      private

        def token_for(deployment)
          AccessToken.fetch(deployment, [Membership::SCOPE],
                            signing_key: Lti::KeyManager.private_key)
        end

        def learners(members)
          members.select { |member| Array(member["roles"]).include?(Membership::LEARNER) }
        end
    end
  end
end
