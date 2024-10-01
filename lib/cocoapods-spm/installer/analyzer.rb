require "cocoapods-spm/installer/validator"

module Pod
  class Installer
    class SPMAnalyzer
      attr_reader :spm_pkgs, :spm_dependencies_by_target

      def initialize(podfile, aggregate_targets)
        @podfile = podfile
        @aggregate_targets = aggregate_targets
        @spm_pkgs = []
        @spm_dependencies_by_target = {}
      end

      def analyze
        analyze_spm_pkgs
        analyze_spm_dependencies_by_target
        validate!
      end

      def spm_dependencies_for(target)
        @spm_dependencies_by_target[target.to_s]
      end

      private

      def analyze_spm_pkgs
        @spm_pkgs = @podfile.target_definition_list.flat_map(&:spm_pkgs).uniq
      end

      def analyze_spm_dependencies_by_target
        analyze_dependencies_for_targets
        analyze_dependencies_for_aggregate_targets
        @spm_dependencies_by_target.values.flatten.each { |d| d.pkg = spm_pkg_for(d.name) }
      end

      def analyze_dependencies_for_targets
        specs = @aggregate_targets.flat_map(&:specs).uniq
        specs.each do |spec|
          if !spec.name.include?('Test')
            @spm_dependencies_by_target[spec.name] = spec.spm_dependencies
          else
            # Replace "/Tests" if it's at the end of the string
            @spm_dependencies_by_target[spec.name.sub(/\/Tests\z/, '-Unit-Tests')] = spec.spm_dependencies
          end
        end
      end

      def analyze_dependencies_for_aggregate_targets
        @aggregate_targets.each do |target|
          spm_dependencies = target.specs.flat_map(&:spm_dependencies)
          if !target.name.include?('Test')
            spm_dependencies = spm_dependencies.reject(&:mp_test_pckg?)
          end
          @spm_dependencies_by_target[target.to_s] = merge_spm_dependencies(spm_dependencies)
        end

        @podfile.spm_pkgs_by_aggregate_target.each do |target, pkgs|
          existing = @spm_dependencies_by_target[target].to_a
          spm_dependencies = pkgs.flat_map(&:to_dependencies)
          @spm_dependencies_by_target[target] = merge_spm_dependencies(existing + spm_dependencies)
        end
      end

      def merge_spm_dependencies(deps)
        deps_by_name = Hash.new { |h, k| h[k] = [] }
        deps.each { |d| deps_by_name[d.name] << d }
        deps_by_name.each do |name, ds|
          deps_by_name[name] = ds.uniq { |d| [d.name, d.product] }
        end
        deps_by_name.values.flatten
      end

      def spm_pkg_for(name)
        @_spm_pkgs_by_name ||= @spm_pkgs.to_h { |pkg| [pkg.name, pkg] }
        @_spm_pkgs_by_name[name]
      end

      def validate!
        validator = SPMValidator.new(@aggregate_targets, @spm_pkgs, @spm_dependencies_by_target)
        validator.validate!
      end
    end
  end
end
