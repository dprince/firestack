require 'yaml'

namespace :build do
    desc "Build all packages."
    task :packages => :distro_name do

        build_name=ENV['NAME']

        config=YAML.load_file("#{KYTOON_PROJECT}/config/packages/#{ENV['DISTRO_NAME']}.yml")
        hostnames = []

        saved_env = ENV.to_hash
        config["package_builds"].each do |build|
            name = build["name"]
            url = build["url"]
            branch = build["branch"] || "master"
            git_master = build["git_master"]
            revision = build["revision"]
            merge_master = build["merge_master"] == true ? "true" : ""
            packager_url = build["packager_url"]
            packager_branch = build["packager_branch"] || "master"
            build_docs = build["build_docs"] || ""

            ENV["PROJECT_NAME"] = name
            ENV["SOURCE_URL"] = url
            ENV["SOURCE_BRANCH"] = branch
            ENV["GIT_MASTER"] = git_master
            ENV["REVISION"] = revision
            ENV["MERGE_MASTER"] = merge_master
            ENV["PACKAGER_URL"] = packager_url
            ENV["PACKAGER_BRANCH"] = packager_branch
            ENV["BUILD_DOCS"] = build_docs

            if build_name.nil? or build_name == name then
                Rake::Task["#{ENV['DISTRO_NAME']}:build_packages"].execute
            end
        end

        ENV.clear
        ENV.update(saved_env)

    end
end
