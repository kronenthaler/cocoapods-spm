require "cocoapods-spm/hooks/base"

module Pod
  module SPM
    class Hook
      class UpdateEmbedFrameworksScript < Hook
        def run
          aggregate_targets.each do |target|
            next if framework_paths_for(target).empty?

            update_embed_frameworks_script(target)
            user_build_configurations.each_key do |config|
              update_embed_frameworks_script_files_path(target, config)
            end
          end
        end

        private

        def framework_paths_for(target)
          @dynamic_deps_by_target ||=
            @spm_analyzer
            .spm_dependencies_by_target
            .transform_values { |deps| deps.select(&:dynamic?) }
          if !target.name.include?('Test')
            @dynamic_deps_by_target[target.to_s] = @dynamic_deps_by_target[target.to_s].reject(&:mp_test_pckg?)
          end
          @dynamic_deps_by_target[target.to_s].map do |d|
            "${BUILT_PRODUCTS_DIR}/PackageFrameworks/#{d.product}.framework"
          end
        end

        def update_embed_frameworks_script(target)
          lines = framework_paths_for(target).map { |p| "install_framework \"#{p}\"" }
          target.embed_frameworks_script_path.open("a") do |f|
            f << "\n" << <<~SH
              # --------------------------------------------------------
              # Added by `cocoapods-spm` to embed SPM package frameworks
              # --------------------------------------------------------
              #{lines.join("\n")}
              # --------------------------------------------------------
            SH
          end
        end

        def file_contains_line?(file_path, search_string)
          File.foreach(file_path) do |line|
            return true if line.include?(search_string)
          end
          false
        end

        def update_embed_frameworks_script_files_path(target, config)
          input_paths = framework_paths_for(target)
          output_paths = input_paths.sort.map do |p|
            "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/#{File.basename(p)}"
          end
          target.embed_frameworks_script_input_files_path(config).open("a+") do |file|
            input_paths.uniq.each do |line|
              unless file_contains_line?(file.path, line)
                file << "\n" << line
              end
            end
          end
          target.embed_frameworks_script_output_files_path(config).open("a+") do |file|
            output_paths.uniq.each do |line|
              unless file_contains_line?(file.path, line)
                file << "\n" << line
              end
            end
          end
        end
      end
    end
  end
end
