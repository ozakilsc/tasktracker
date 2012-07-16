class ProjectUser < ActiveRecord::Base
  attr_accessible :user_id, :invite_email, :creator_id, :allow_editing

  # Model Validation
  validates_presence_of :project_id, :creator_id #, :user_id
  validates_uniqueness_of :invite_token, allow_nil: true

  # Model Relationships
  belongs_to :project
  belongs_to :user
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'

  after_update :notify_user

  def generate_invite_token!(invite_token = SecureRandom.hex(64))
    begin
      self.update_attribute :invite_token, invite_token if self.respond_to?('invite_token') and self.invite_token.blank? and ProjectUser.where(invite_token: invite_token).count == 0
      UserMailer.invite_user_to_project(self).deliver if Rails.env.production? and not self.invite_token.blank?
    rescue ActiveRecord::RecordNotUnique
      # Do nothing
    end
  end

  private

  def notify_user
    UserMailer.user_added_to_project(self).deliver if Rails.env.production? and self.invite_token.blank?
  end
end
