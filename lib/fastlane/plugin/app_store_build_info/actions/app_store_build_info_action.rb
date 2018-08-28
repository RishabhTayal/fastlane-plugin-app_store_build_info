require 'fastlane/action'
require_relative '../helper/app_store_build_info_helper'

module Fastlane
  module Actions

    module SharedValues
      LATEST_BUILD_NUMBER = :LATEST_BUILD_NUMBER
      LATEST_VERSION_NUMBER = :LATEST_VERSION_NUMBER
    end

    class AppStoreBuildInfoAction < Action
      def self.run(params)
        require 'spaceship'

        build_info = get_build_info(params)

        build_nr = build_info[:latest_build_number]

        # Convert build_nr to int (for legacy use) if no "." in string
        if build_nr.kind_of?(String) && !build_nr.include?(".")
          build_nr = build_nr.to_i
        end

        Actions.lane_context[SharedValues::LATEST_BUILD_NUMBER] = build_nr

        unless build_nr.nil?
          build_info[:latest_build_number] = build_nr
        end
        build_info
      end

      def self.get_build_info(params)
        UI.message("Login to iTunes Connect (#{params[:username]})")
        Spaceship::Tunes.login(params[:username])
        Spaceship::Tunes.select_team(team_id: params[:team_id], team_name: params[:team_name])
        UI.message("Login successful")
        
        platform = params[:platform]

        app = Spaceship::Tunes::Application.find(params[:app_identifier])
        if params[:live]
          UI.message("Fetching the latest build number for live-version")
          live_version = app.live_version
          unless live_version.nil?
            build_nr = live_version.current_build_number
            Actions.lane_context[SharedValues::LATEST_VERSION_NUMBER] = live_version.version
            version_number = live_version.version
          end
        else
          version_number = params[:version]
          unless version_number
            # Automatically fetch the latest version in testflight
            begin
              train_numbers = app.all_build_train_numbers(platform: platform)
              testflight_version = self.order_versions(train_numbers).last
            rescue
              testflight_version = params[:version]
            end

            if testflight_version
              version_number = testflight_version
            else
              version_number = UI.input("You have to specify a new version number, as there are multiple to choose from")
            end

          end

          Actions.lane_context[SharedValues::LATEST_VERSION_NUMBER] = version_number

          UI.message("Fetching the latest build number for version #{version_number}")

          begin
            build_numbers = app.all_builds_for_train(train: version_number, platform: platform).map(&:build_version)
            build_nr = self.order_versions(build_numbers).last
            if build_nr.nil? && params[:initial_build_number]
              UI.message("Could not find a build on iTC. Using supplied 'initial_build_number' option")
              build_nr = params[:initial_build_number]
            end
          rescue
            UI.user_error!("Could not find a build on iTC - and 'initial_build_number' option is not set") unless params[:initial_build_number]
            build_nr = params[:initial_build_number]
          end
        end
        UI.message("Latest upload for version #{version_number} is build: #{build_nr}")

        {
          latest_build_number: build_nr,
          latest_version_number: version_number
        }
      end

      def self.order_versions(versions)
        versions.map(&:to_s).sort_by { |v| Gem::Version.new(v) }
      end

      def self.description
        "Get build info from App Store Connect"
      end

      def self.authors
        ["Rishabh Tayal"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Get build info for an app, like version number and build number from App Store Connect"
      end

      def self.output
        [
          ['LATEST_BUILD_NUMBER', 'The latest build number of either live or testflight version'],
          ['LATEST_VERSION_NUMBER', 'The latest version number of either live or testflight version']
        ]
      end

      def self.available_options
        user = CredentialsManager::AppfileConfig.try_fetch_value(:itunes_connect_id)
        user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)
        [
          FastlaneCore::ConfigItem.new(key: :initial_build_number,
                                       env_name: "INITIAL_BUILD_NUMBER",
                                       description: "sets the build number to given value if no build is in current train",
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                       short_option: "-a",
                                       env_name: "FASTLANE_APP_IDENTIFIER",
                                       description: "The bundle identifier of your app",
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
                                       default_value_dynamic: true),
          FastlaneCore::ConfigItem.new(key: :username,
                                       short_option: "-u",
                                       env_name: "ITUNESCONNECT_USER",
                                       description: "Your Apple ID Username",
                                       default_value: user,
                                       default_value_dynamic: true),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       short_option: "-k",
                                       env_name: "APPSTORE_BUILD_INFO_LIVE_TEAM_ID",
                                       description: "The ID of your iTunes Connect team if you're in multiple teams",
                                       optional: true,
                                       is_string: false, # as we also allow integers, which we convert to strings anyway
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_id),
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :live,
                                       short_option: "-l",
                                       env_name: "APPSTORE_BUILD_INFO_LIVE",
                                       description: "Query the live version (ready-for-sale)",
                                       optional: true,
                                       is_string: false,
                                       default_value: true),
          FastlaneCore::ConfigItem.new(key: :version,
                                       env_name: "LATEST_VERSION",
                                       description: "The version number whose latest build number we want",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       short_option: "-j",
                                       env_name: "APPSTORE_PLATFORM",
                                       description: "The platform to use (optional)",
                                       optional: true,
                                       is_string: true,
                                       default_value: "ios",
                                       verify_block: proc do |value|
                                         UI.user_error!("The platform can only be ios, appletvos, or osx") unless %('ios', 'appletvos', 'osx').include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :team_name,
                                       short_option: "-e",
                                       env_name: "LATEST_TESTFLIGHT_BUILD_NUMBER_TEAM_NAME",
                                       description: "The name of your iTunes Connect team if you're in multiple teams",
                                       optional: true,
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_name),
                                       default_value_dynamic: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                       end)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
