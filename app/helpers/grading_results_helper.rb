# frozen_string_literal: true

module GradingResultsHelper
  def visible_test_groups(result, reveal_hidden)
    snapshot = result.suite_snapshot["groups"] || []
    result.breakdown.each_with_index.map do |group, i|
      passed = Array(group["cases"]).all? { |c| c["passed"] }
      hidden = snapshot.dig(i, "hidden") && !reveal_hidden
      { "label" => group["label"], "passed" => passed, "hidden" => hidden,
        "inputs" => hidden ? nil : snapshot.dig(i, "inputs"),
        "outputs" => hidden ? nil : snapshot.dig(i, "outputs") }
    end
  end
end
