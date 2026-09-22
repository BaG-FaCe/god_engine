module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # US Treasury OFAC Specially Designated Nationals (SDN) list.
        #
        # Same architecture as the EU sanctions provider: the CSV is mirrored into
        # `sanctions_entries` (source `ofac_sdn`) by `sync_list!` so screening keeps
        # working when the OFAC host is unreachable, and every response reports
        # the list date so staleness is visible.
        class OfacSdnProvider < Domain::RiskDataProvider
          ENDPOINT = 'https://sanctionslistservice.ofac.treas.gov/api/PublicationPreview/exports/SDN.CSV'
          SOURCE = 'ofac_sdn'
          LIST_NAME = 'US OFAC SDN List'

          MATCH_SCORE = 95
          PARTIAL_MATCH_SCORE = 70
          COUNTRY_OF_CONCERN_SCORES = {
            'RU' => 50, 'BY' => 45, 'IR' => 60, 'KP' => 70, 'SY' => 55, 'CU' => 40,
            'VE' => 45, 'MM' => 45
          }.freeze
          CLEAR_SCORE = 8

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('ofac_sdn')
            end
          end

          def assess(subject)
            name = subject.supplier_name.presence
            country = Support.country_code(subject.origin_country)
            return nil if name.blank? && country.blank?

            match = name.present? ? find_match(name) : nil
            score, reason = evaluate(match, name, country)

            draft(
              risk_score: score,
              dimensions: { 'compliance' => score, 'geopolitical' => (score * 0.8).round },
              reason: reason,
              data_sources: [LIST_NAME],
              raw_payload: match,
              confidence: BigDecimal('0.9')
            )
          end

          # Downloads the current list into `sanctions_entries`. Called by
          # SupplyChainRisk::RefreshSanctionsListJob, never from a web request.
          def sync_list!
            csv = download
            return 0 if csv.blank?

            imported = 0
            CSV.parse(csv, headers: false, liberal_parsing: true).each do |row|
              entry = build_entry(row)
              next if entry.nil?

              SanctionsEntry.upsert(entry, unique_by: %i[source entity_name])
              imported += 1
            end
            context.log(:info, 'OFAC-SDN-Liste synchronisiert', entries: imported)
            imported
          end

          private

          def download
            context.http.get(
              ENDPOINT,
              headers: { 'Accept' => 'text/csv' },
              provider_key: key,
              max_wait: 60
            )
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:error, 'OFAC-Liste konnte nicht geladen werden', error: e.message)
            nil
          end

          # The SDN CSV has no header row. The fixed column layout is:
          #   0 ent_num | 1 SDN Name | 2 SDN Type | 3 Program |
          #   4 Title | 5 Call Sign | 6 Vessel Type | 7 Tonnage |
          #   8 GRT | 9 Vessel Flag | 10 Vessel Owner | 11 Remarks
          def build_entry(row)
            name = row[1].to_s.strip
            return nil if name.blank?

            {
              source: SOURCE,
              list_name: LIST_NAME,
              entity_name: name.truncate(255),
              normalised_name: SanctionsEntry.normalise(name),
              entity_type: entity_type(row[2]),
              country_code: nil,
              program: row[3].to_s.presence,
              listed_on: nil,
              aliases: [],
              identifiers: { entNum: row[0].to_s.presence, remarks: row[11].to_s.presence }.compact,
              created_at: Time.current,
              updated_at: Time.current
            }
          end

          def entity_type(value)
            type = value.to_s.downcase
            return 'individual' if type == 'individual'
            return 'vessel' if type.include?('vessel')
            return 'aircraft' if type.include?('aircraft')

            'entity'
          end

          def find_match(name)
            exact = SanctionsEntry.by_source(SOURCE).merge(SanctionsEntry.search(name)).first
            return exact if exact

            SanctionsEntry.by_source(SOURCE).merge(SanctionsEntry.search_loosely(name)).first
          end

          def evaluate(match, name, country)
            if match
              exact = SanctionsEntry.normalise(match.entity_name) == SanctionsEntry.normalise(name)
              return [exact ? MATCH_SCORE : PARTIAL_MATCH_SCORE,
                      "#{name} steht auf der OFAC-SDN-Liste (#{match.entity_name})"]
            end

            country_score = COUNTRY_OF_CONCERN_SCORES[country]
            return [country_score, "Herkunftsland #{country} unterliegt OFAC-Beschraenkungen"] if country_score

            [CLEAR_SCORE, 'Kein OFAC-Treffer fuer Lieferant und Herkunftsland']
          end
        end
      end
    end
  end
end
