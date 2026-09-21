# Custom inflections.
#
# Deliberately EMPTY: no acronyms are registered.
#
# `ActiveSupport::Inflector#camelize` expands registered acronyms per underscore
# separated segment, so registering e.g. `JSON` makes Zeitwerk expect
# `JsonClient` to be named `JSONClient`, and registering `TARIC` would turn
# `EuTaricProvider` into `EuTARICProvider`. Both are silent, confusing failures at
# eager-load time.
#
# The convention here is therefore plain camel case (`JsonClient`, `EuTaricProvider`,
# `CsvExporter`, `XlsxExporter`, `PdfExporter`) which keeps file name and constant
# name in a one-to-one relationship - the property Zeitwerk depends on.
#
# Add an acronym only together with the matching file and class rename.

# Example of a safely scoped inflection if one is ever needed:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.irregular 'person', 'people'
# end
