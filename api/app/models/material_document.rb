# Attachment metadata for a material (datasheets, CAD files, certificates).
#
# Files are referenced by URL rather than stored in the database: the API stays
# stateless and the SQLite file stays small. `MaterialDocuments::Store` keeps the
# URL convention in one place so switching to Active Storage or S3 later only
# touches that one class.
class MaterialDocument < ApplicationRecord
  KINDS = %w[datasheet cad certificate image other].freeze

  belongs_to :material, inverse_of: :material_documents

  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true, length: { maximum: 255 }
  validates :url, presence: true
  validates :byte_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                        allow_nil: true

  scope :ordered, -> { order(:kind, :name) }
  scope :datasheets, -> { where(kind: 'datasheet') }

  def human_size
    return nil if byte_size.nil?

    units = %w[B KB MB GB]
    size = byte_size.to_f
    index = 0
    while size >= 1024 && index < units.length - 1
      size /= 1024
      index += 1
    end
    format('%.1f %s', size, units[index])
  end
end