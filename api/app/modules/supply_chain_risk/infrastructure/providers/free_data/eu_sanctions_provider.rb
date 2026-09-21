module SupplyChainRisk
  module Infrastructure
    module Providers
      module FreeData
        # EU consolidated financial sanctions list.
        #
        # The Commission publishes the list as a CSV. Screening must keep working
        # when the EU host is unreachable (which happens during maintenance
        # windows), so the list is *cached in the application database*
        # (`sanctions_entries`) rather than in the cache store: a result based on a
        # two day old list is still worth more than an error, and every response
        # reports the list date so the staleness is visible.
        class EuSanctionsProvider < Domain::RiskDataProvider
          # Public token used by the FSD full-list download endpoint.
          ENDPOINT = 'https://webgate.ec.europa.eu/fsd/fsf/public/files/csvFullSanctionsList_1_1/content'
          PUBLIC_TOKEN = 'dG9rZW4tMjAxNw'
          SOURCE = 'eu_consolidated'
          LIST_NAME = 'EU Konsolidierte Liste'

          MATCH_SCORE = 95
          PARTIAL_MATCH_SCORE = 70
          COUNTRY_OF_CONCERN_SCORES = {
            'RU' => 45, 'BY' => 45, 'IR' => 55, 'KP' => 70, 'SY' => 55, 'MM' => 45,
            'AF' => 40, 'LY' => 40, 'VE' => 40, 'CU' => 35
          }.freeze
          CLEAR_SCORE = 8

          class << self
            def descriptor
              @descriptor ||= Infrastructure::ProviderCatalogue.find!('eu_sanctions')
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
              data_sources: ['EU Konsolidierte Sanktionsliste'],
              raw_payload: match,   # echtes Namensfeld wurde bereits maskiert
              confidence: BigDecimal('0.9')
            )
          end

          # Downloads the current list into `sanctions_entries`. Called by
          # SupplyChainRisk::RefreshSanctionsListJob, never from a web request.
          def sync_list!
            csv = download
            return 0 if csv.blank?

            imported = 0
            CSV.parse(csv, headers: true, liberal_parsing: true) do |row|
              entry = build_entry(row)
              next if entry.nil?

              SanctionsEntry.upsert(entry, unique_by: %i[source entity_name])
              imported += 1
            end
            context.log(:info, 'Sanktionsliste synchronisiert', entries: imported)
            imported
          end

          private

          def download
            context.http.get(
              ENDPOINT,
              params: { token: PUBLIC_TOKEN },
              headers: { 'Accept' => 'text/csv' },
              provider_key: key,
              max_wait: 60
            )
          rescue Shared::Infrastructure::Http::JsonClient::Error => e
            context.log(:error, 'Sanktionsliste konnte nicht geladen werden', error: e.message)
            nil
          end

          # The CSV column names differ between publications, so both the German
          # and the English variants are accepted.
          def build_entry(row)
            name = column(row, 'NameAlias', 'Name', 'nameAlias', 'EntityName')
            return nil if name.blank?

            {
              source: SOURCE,
              list_name: LIST_NAME,
              entity_name: name.to_s.truncate(255),
              normalised_name: SanctionsEntry.normalise(name),
              entity_type: entity_type(row),
              country_code: Support.country_code(column(row, 'Citizenship', 'Country')),
              program: column(row, 'Regulation', 'Programme'),
              listed_on: parse_date(column(row, 'ListedOn', 'DateOfPublication')),
              aliases: [column(row, 'Alias', 'NameAliasStrong')].compact,
              identifiers: { remark: column(row, 'Remark'), 'eu_reference': column(row, 'EuReference') }.compact,
              created_at: Time.current,
              updated_at: Time.current
            }
          end

          def entity_type(row)
            value = column(row, 'SubjectType', 'Type').to_s.downcase
            return 'individual' if value.include?('person') || value.include?('natural')
            return 'vessel' if value.include?('ship') || value.include?('vessel')

            'entity'
          end

          def column(row, *names)
            names.each do |name|
              value = row[name]
              return value if value.present?
            end
            nil
          end

          def parse_date(value)
            return nil if value.blank?

            Date.parse(value.to_s)
          rescue ArgumentError, TypeError
            nil
          end

          def find_match(name)
            exact = SanctionsEntry.search(name).first
            return exact if exact

            SanctionsEntry.search_loosely(name).first
          end

          def evaluate(match, name, country)
            if match
              exact = SanctionsEntry.normalise(match.entity_name) == SanctionsEntry.normalise(name)
              return [exact ? MATCH_SCORE : PARTIAL_MATCH_SCORE,
                      "#{name} steht auf der EU-Sanktionsliste (#{match.entity_name})"]
            end

            country_score = COUNTRY_OF_CONCERN_SCORES[country]
            if country_score
              return [country_score,
                      "Herkunftsland #{country} unterliegt EU-Beschraenkungen"]
            end

            [CLEAR_SCORE, 'Kein Sanktionstreffer fuer Lieferant und Herkunftsland']
          end
        end
      end
    end
  end
end