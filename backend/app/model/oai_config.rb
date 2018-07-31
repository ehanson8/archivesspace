class OAIConfig < Sequel::Model(:oai_config)
  include ASModel
  corresponds_to JSONModel(:oai_config)

  set_model_scope :global

  # validations
  # only one row in table allowed
  # oai_repository_name must have a value
  # oai_admin_email must have a value and be an email address
  # oai_record_prefix must have a value

  def validate
  	validate_single_record

  	validates_presence :oai_record_prefix
  	validates_presence :oai_admin_email
  	validates_presence :oai_repository_name

    validate_oai_admin_email_is_email
  end

  def validate_single_record
  	record_count = OAIConfig.all.count

  	unless record_count == 0
      # if we have an existing record, we'd better be updating that one record
      first_record = OAIConfig.first

      if self.id.nil? || first_record.id != self.id
        errors.add(:base, 'Cannot have more than one record in oai_config table.') 
      end
  	end
  end

  def validate_oai_admin_email_is_email
    unless self.oai_admin_email =~ /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i
      errors.add(:oai_admin_email, 'must be a valid email address.') 
    end
  end

end