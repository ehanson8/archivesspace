class ARKIdentifier < Sequel::Model(:ark_identifier)
  include ASModel

  one_to_one :resource  
  one_to_one :accession
  one_to_one :digital_object

  # validations:
  # must be linked to a resource, accession or digital object
  # cannot link to more than one type of resource
  # can't have more than one ark_id point to the same resource, accession and digital_object

  def validate
    validate_resources_defined
    validates_unique(:resource_id, :message => "ARK must point to a unique Resource")
    validates_unique(:accession_id, :message => "ARK must point to a unique Accession")
    validates_unique(:digital_object_id, :message => "ARK must point to a unique Digital Object")
    super
  end

  def validate_resources_defined
    resources_defined = 0
    resources_defined += 1 unless self.resource_id.nil?
    resources_defined += 1 unless self.accession_id.nil?
    resources_defined += 1 unless self.digital_object_id.nil?

    unless resources_defined == 1
      errors.add(:base, 'Exactly one of [resource_id, digital_object_id, accession_id] must be defined.') 
    end
  end

  def self.create_from_resource(resource)
    # check if we have an external ID we need to handle
    # self.identifier is a String representation of an array, like:
    # "[\"https://n2t.net/ark:/00001/f1mw5e\",null,null,null]"
    # We need to remove superflous charaters so we can turn it into an actual array.

    id_ary = resource.identifier.gsub('[', "").gsub(']', "").gsub('"', '').split(",")
    id = nil
    id_ary.each {|i| id = i if i =~ /ark:\//}

    self.insert(:resource_id      => resource.id,
                :created_by       => 'admin',
                :last_modified_by => 'admin',
                :create_time      => Time.now,
                :system_mtime     => Time.now,
                :user_mtime       => Time.now,
                :external_id      => id,
                :lock_version     => 0)
  end

  def self.create_from_accession(accession)
    # same deal as above
    id_ary = accession.identifier.gsub('[', "").gsub(']', "").gsub('"', '').split(",")
    id = nil
    id_ary.each {|i| id = i if i =~ /ark:\//}

    self.insert(:accession_id     => accession.id,
                :created_by       => 'admin',
                :last_modified_by => 'admin',
                :create_time      => Time.now,
                :system_mtime     => Time.now,
                :user_mtime       => Time.now,
                :external_id      => id,
                :lock_version     => 0)
  end

  def self.create_from_digital_object(digital_object)
    id = digital_object.digital_object_id =~ /ark:\// ? digital_object.digital_object_id : nil

    self.insert(:digital_object_id => digital_object.id,
                :created_by        => 'admin',
                :last_modified_by  => 'admin',
                :create_time       => Time.now,
                :system_mtime      => Time.now,
                :user_mtime        => Time.now,
                :external_id      => id,
                :lock_version      => 0)
  end
end