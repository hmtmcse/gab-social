# frozen_string_literal: true
# == Schema Information
#
# Table name: link_blocks
#
#  id         :bigint(8)        not null, primary key
#  link       :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class LinkBlock < ApplicationRecord
  include LinkNormalizable

  validates :link, presence: true, uniqueness: true

  scope :alphabetical, -> { reorder(link: :asc) }

  def self.block?(text)
    return false if text.nil?
    return false if text.length < 1

    return true if text.include? '.weebly.com'

    urls = text.scan(FetchLinkCardService::URL_PATTERN).map {|array|
      Addressable::URI.parse(array[0]).normalize
    }
    url = urls.first

    return false if url.nil?

    link_for_fetch = TagManager.instance.normalize_link(url)
    link_for_fetch = link_for_fetch.chomp("/")

    domain_for_fetch = TagManager.instance.normalize_link_domain(url)

    where("LOWER(link) LIKE LOWER(?)", "%#{link_for_fetch}").or(
      where("LOWER(link) LIKE LOWER(?)", "#{domain_for_fetch}")
    ).exists?
  end
end
