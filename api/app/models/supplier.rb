# Supplier master data within a project. Sanctions fields are written by the
# `supply-chain-risk` module (free EU/OFAC list check or a paid screening API).
class Supplier < ApplicationRecord
  SANCTIONS_STATUSES = %w[clear flagged unknown pending].freeze

  belongs_to :project
  has_many :materials, dependent: :nullify
  has_many :alternative_suppliers, dependent: :nullify

  validates :name, presence: true, length: { maximum: 200 }
  validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :sanctions_status, inclusion: { in: SANCTIONS_STATUSES }
  validate :country_code_format

  scope :ordered, -> { order(:name) }
  scope :flagged, -> { where(sanctions_status: 'flagged') }
  scope :single_source, -> { where(is_single_source: true) }

  def flagged?
    sanctions_status == 'flagged'
  end

  def apply_sanctions_result!(status:, details: nil)
    update!(
      sanctions_status: status,
      sanctions_details: details,
      sanctions_checked_at: Time.current
    )
  end

  private

  def country_code_format
    return if country.blank? || country.length == 2

    errors.add(:country, 'muss ein ISO-3166-Alpha-2-Code sein')
  end
end