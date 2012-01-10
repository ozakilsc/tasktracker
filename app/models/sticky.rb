class Sticky < ActiveRecord::Base
  serialize :tags, Array

  # Named Scopes
  scope :current, conditions: { deleted: false }
  scope :with_project, lambda { |*args| { conditions: ["stickies.project_id IN (?) or (stickies.project_id IS NULL and stickies.user_id = ?)", args.first, args[1]] } }
  scope :with_creator, lambda { |*args|  { conditions: ["stickies.user_id IN (?)", args.first] } }
  scope :with_owner, lambda { |*args|  { conditions: ["stickies.owner_id IN (?) or stickies.owner_id IS NULL", args.first] } }
  scope :with_frame, lambda { |*args| { conditions: ["stickies.frame_id IN (?) or (stickies.frame_id IS NULL and 0 IN (?))", args.first, args.first] } }
  scope :search, lambda { |*args| { conditions: [ 'LOWER(description) LIKE ? or LOWER(tags) LIKE ? or stickies.group_id IN (select groups.id from groups where LOWER(groups.description) LIKE ?)', '%' + args.first.downcase.split(' ').join('%') + '%', '%' + args.first.downcase.split(' ').join('%') + '%', '%' + args.first.downcase.split(' ').join('%') + '%' ] } }
  scope :updated_since, lambda { |*args| { conditions: ["stickies.updated_at > ?", args.first] }}
  scope :with_date_for_calendar, lambda { |*args| { conditions: ["DATE(stickies.created_at) >= ? and DATE(stickies.created_at) <= ?", args.first, args[1]]}}
  
  scope :with_due_date_for_calendar, lambda { |*args| { conditions: ["DATE(stickies.due_date) >= ? and DATE(stickies.due_date) <= ?", args.first, args[1]]}}
  
  scope :due_date_within, lambda { |*args| { conditions: ["(DATE(stickies.due_date) >= ? or ? IS NULL) and (DATE(stickies.due_date) <= ? or ? IS NULL)", args.first, args.first, args[1], args[1]] }}
  
  
  scope :with_start_date_for_calendar, lambda { |*args| { conditions: ["DATE(stickies.start_date) >= ? and DATE(stickies.start_date) <= ?", args.first, args[1]]}}
  scope :with_end_date_for_calendar, lambda { |*args| { conditions: ["DATE(stickies.end_date) >= ? and DATE(stickies.end_date) <= ?", args.first, args[1]]}}
  # scope :with_due_date_for_calendar, lambda { |*args| { conditions: ["DATE(stickies.due_date) >= ? and DATE(stickies.due_date) <= ? or (stickies.due_date IS NULL and stickies.frame_id in (select frames.id from frames where DATE(frames.end_date) >= ? and DATE(frames.end_date) <= ?))", args.first, args[1], args.first, args[1]]}}

  scope :due_today,     lambda { |*args| { conditions: ["stickies.completed = ? and DATE(stickies.due_date) = ?", false, Date.today]}}
  scope :past_due,      lambda { |*args| { conditions: ["stickies.completed = ? and DATE(stickies.due_date) < ?", false, Date.today]}}
  scope :due_this_week, lambda { |*args| { conditions: ["stickies.completed = ? and DATE(stickies.due_date) > ? and DATE(stickies.due_date) < ?", false, Date.today, Date.today + (7-Date.today.wday).days]}}

  # scope :with_tags, lambda { |*args| { conditions: ["stickies.tags IN (?)", args.first] } }
  scope :with_tag, lambda { |*args| { conditions: [ "stickies.tags LIKE ?", '%- ' + args.first + '%' ] } }

  before_create :set_start_date
  after_create :send_email
  
  before_save :set_end_date, :set_project_and_frame
  after_save :send_completion_email

  # Model Validation
  validates_presence_of :description, :project_id

  # Model Relationships
  belongs_to :user
  belongs_to :project, touch: true
  belongs_to :group
  belongs_to :frame

  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id' 

  def name
    "ID ##{self.id}"
  end

  def destroy
    self.comments.destroy_all
    update_attribute :deleted, true
  end
  
  def comments(limit = nil)
    Comment.current.with_class_name(self.class.name).with_class_id(self.id).order('created_at desc').limit(limit)
  end
  
  def new_comment(current_user, description)
    Comment.create(class_name: self.class.name, class_id: self.id, user_id: current_user.id, description: description)
    self.touch
  end

  def full_description
    @full_description ||= begin
      if self.group and not self.group.description.blank?
        self.description + "\n\n" + self.group.description
      else
        self.description
      end
    end
  end

  def shift_group(days_to_shift, shift)
    if days_to_shift != 0 and self.group and ['incomplete', 'all'].include?(shift)
      sticky_scope = self.group.stickies.where("stickies.id != ?", self.id)
      sticky_scope = sticky_scope.where(completed: false) if shift == 'incomplete'
      sticky_scope.select{ |s| not s.due_date.blank? }.each{ |s| s.update_attribute :due_date, s.due_date + days_to_shift.days }
    end
  end

  private
    
  def send_email
    if not self.group and not self.completed?
      all_users = self.project.users_to_email(:sticky_creation) - [self.user]
      all_users.each do |user_to_email|
        UserMailer.sticky_by_mail(self, user_to_email).deliver if Rails.env.production?
      end
    end
  end

  # TODO: Currently assumes that the owner marks the sticky as completed.
  def send_completion_email
    if self.changes[:completed] and self.changes[:completed][1] == true and self.owner
      all_users = self.project.users_to_email(:sticky_completion) - [self.owner]
      all_users.each do |user_to_email|
        UserMailer.sticky_completion_by_mail(self, user_to_email).deliver if Rails.env.production?
      end
    end
  end

  def set_start_date
    self.start_date = Date.today
  end

  def set_end_date
    self.end_date = ((self.changes[:completed] and self.changes[:completed][1] == true) ? Date.today : nil) unless self.completed? and self.changes[:completed] == nil
  end

  def set_project_and_frame
    if self.group
      self.project_id = self.group.project_id
      if not self.group.project.frames.collect{|f| f.id}.include?(self.frame_id) and self.changes[:frame_id]
        self.frame_id = self.changes[:frame_id][0]
      end
    end
  end

end
