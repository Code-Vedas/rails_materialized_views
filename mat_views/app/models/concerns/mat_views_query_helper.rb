# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# MatViewsPaginate
# ----------------
#
module MatViewsQueryHelper
  extend ActiveSupport::Concern

  class_methods do
    def ordered_by_enum(enum_values:, enum_name:, direction:)
      enum_pairs = enum_values.map do |name, int|
        [int, human_enum_name(enum_name, name)]
      end
      enum_pairs.sort_by! { |(_int, label)| label.to_s.downcase }

      when_sql = enum_pairs.each_with_index
                           .map { |(enum_int, _label), search_enum_int| "WHEN #{enum_int} THEN #{search_enum_int}" }
                           .join(' ')

      order(Arel.sql("CASE #{table_name}.#{enum_name} #{when_sql} ELSE #{enum_pairs.size} END #{direction.to_s.downcase}"))
    end

    def search_by_enum(enum_values:, enum_name:, term:)
      enum_pairs = enum_values.map do |name, int|
        [int, human_enum_name(enum_name, name)]
      end
      selected = enum_pairs.select { |(_int, label)| label.to_s.downcase.include?(term.downcase) }.map { |(int, _label)| int }
      where(enum_name => selected)
    end
  end
end
