class User < ActiveRecord::Base
	has_many :microposts, dependent: :destroy
	has_many :active_relationships, class_name: "Relationship",
									foreign_key: "follower_id",
									dependent: :destroy
	has_many :passive_relationships, class_name: "Relationship",
									foreign_key: "followed_id",
									dependent: :destroy
	has_many :following, through: :active_relationships, source: :followed
	has_many :followers, through: :passive_relationships, source: :follower

	attr_accessor :remember_token, :activation_token, :reset_token, :reset_sent_at
	before_save :downcase_email
	before_create :create_activation_digest

	VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i


	validates :name, presence: true, length: {maximum: 50}
	validates :email, presence: true, length: {maximum: 255},
						format: {with: VALID_EMAIL_REGEX},
						uniqueness: {case_sensitive: false}

	has_secure_password
	validates :password, length: {minimum: 6}, allow_blank: true

	# Returns the hash digest of the given string
	def User.digest(string)
		cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
		BCrypt::Password.create(string, cost: cost)
	end

	# Returns a random token
	def User.new_token
		SecureRandom.urlsafe_base64
	end

	def User.remember(user)
		user.remember_token = User.new_token
		update_attribute(:remember_digest, User.digest(remember_token))
	end

	def authenticated?(attribute, token)
		digest = self.send("#{attribute}_digest")
		return false if digest.nil?
		BCrypt::Password.new(digest).is_password?(token)
	end

	def forget
		update_attribute(:remember_digest, nil)
	end

	def activate
		update_attribute(:activated, true)
		update_attribute(:activated_at, Time.zone.now)	
	end

	def send_activation_email
		UserMailer.account_activation(self).deliver_now
	end

	def create_reset_digest
		self.reset_token = User.new_token
		update_attribute(:reset_digest, User.digest(reset_token))
		update_attribute(:reset_sent_at, Time.zone.now)
	end

	def send_password_reset_email
		UserMailer.password_reset(self).deliver_now
	end

	def password_reset_expired?
		self.reset_send_at < 2.hour.ago
	end

	def feed
		Micropost.where("user_id IN (?) OR user_id = ?", following_ids, id)
		
	end

	def follow(other_user)
		active_relationships.create(followed_id: other_user.id)
	end

	def unfollow(other_user)
		active_relationships.find_by(followed_id: other_user.id).destroy
	end

	def following?(other_user)
		following.include?(other_user)
	end

	private
		def downcase_email
			self.email = email.downcase
		end

		def create_activation_digest
			self.activation_token = User.new_token
			self.activation_digest = User.digest(activation_token)
		end
end