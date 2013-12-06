class TestCaseRelation < ActiveRecord::Base
  # attr_accessible :title, :body

  include ActiveModel::ForbiddenAttributesProtection

  belongs_to :test_case
  belongs_to :test_set

  validate do |relation|
    errors.add :test_case, "Both test case and test set must belong to the same problem" unless relation.test_set.problem_id == TestCase.where(:id => relation.test_case_id).pluck(:problem_id).first
  end
end
