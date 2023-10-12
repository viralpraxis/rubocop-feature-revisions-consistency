# frozen_string_literal: true

module RuboCop
  module Cop
    module Lint
      # Some features (e.g. method definitions, variables, constants or RoR ActiveRecord DSL)
      # may be logically related in the sense that changes in one without simultaneous
      # changes in the other can lead to violations of business logic, unexpected bugs
      # or application correctness in general.
      # To be able to verify the consistency of the implementations of such features,
      # they can be marked with a special comment of a well-defined format.
      #
      # Configuration options:
      #  - `MagicCommentRegExp`
      #    A valid ruby regular expression with `id` and `revision` named capture groups.
      #
      # @example
      #   # Magic comments with the same id attribute must have identical revisions.
      #
      #   # bad
      #   class User < ApplicationRecord
      #     # [feature-revision] id: user-with-email-query, revision: 3
      #     def with_email?
      #        email.present?
      #     end
      #
      #     # [feature-revision] id: user-with-email-query, revision: 2
      #     def self.with_email
      #        where.not(email: nil)
      #     end
      #   end
      #
      #   # good
      #   class User < ApplicationRecord
      #     # [feature-revision] id: user-with-email-query, revision: 3
      #     def with_email?
      #        email.present?
      #     end
      #
      #     # [feature-revision] id: user-with-email-query, revision: 3
      #     def self.with_email
      #        where.not(email: nil)
      #     end
      class FeatureRevisionsConsistency < Base
        OffendingComment = Struct.new(:node, :data, keyword_init: true) do
          extend Forwardable

          def_delegators :data, :id, :revision

          def initialize(node:, data:)
            super node: node, data: OpenStruct.new(data.named_captures)
          end
        end

        DEFAULT_OPTIONS = {
          magic_comment_regexp: /^\s*#\s*\[feature-revision\]\s*id:\s*(?<id>\S+),\s*revision:\s*(?<revision>\S+)\s*$/
        }.freeze

        ENV_KEY_COP_ENABLED = "RUBOCOP_RUN_CACHELESS_COPS"

        MSG = "Unmatched feature revision"

        include RangeHelp

        # rubocop:disable Style/ClassVars
        @@__data = Hash.new { Set.new }
        @@__mutex = Mutex.new
        # rubocop:enable Style/ClassVars

        # NOTE: Intentionally invalidating cache here because per-file
        # caching is not applicable for this cop.
        def external_dependency_checksum
          @external_dependency_checksum ||= ENV.key?(ENV_KEY_COP_ENABLED) ? SecureRandom.hex : ""
        end

        def on_new_investigation
          return unless processed_source.ast

          investigate
        end

        private

          def investigate
            source_offending_comments(processed_source).each do |comment|
              if has_offending_comment_in_same_group?(comment)
                add_offense comment.node, severity: :error
              end

              store_offending_comment(comment)
            end
          end

          def source_offending_comments(source)
            source.comments.filter_map do |comment|
              if (match_data = magic_comment_regexp.match(comment.text))
                OffendingComment.new(node: comment, data: match_data)
              end
            end
          end

          def has_offending_comment_in_same_group?(comment)
            @@__mutex.synchronize do
              !@@__data[comment.id].empty? && !@@__data[comment.id].include?(comment.revision) # rubocop:disable Rails/NegateInclude
            end
          end

          def store_offending_comment(comment)
            @@__mutex.synchronize do
              @@__data[comment.id] = @@__data[comment.id].add(comment.revision)
            end
          end

          def magic_comment_regexp
            cop_config.fetch("MagicCommentRegExp", DEFAULT_OPTIONS.fetch(:magic_comment_regexp))
          end
      end
    end
  end
end
