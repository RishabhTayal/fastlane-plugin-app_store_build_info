describe Fastlane::Actions::AppstoreBuildInfoAction do
  describe "app_store_build_info" do
	  it "orders versions array of integers" do
	    versions = [3, 5, 1, 0, 4]
	    result = Fastlane::Actions::AppStoreBuildInfoAction.order_versions(versions)

	    expect(result).to eq(['0', '1', '3', '4', '5'])
	  end

	  it "orders versions array of integers and string integers" do
	    versions = [3, 5, '1', 0, '4']
	    result = Fastlane::Actions::AppStoreBuildInfoAction.order_versions(versions)

	    expect(result).to eq(['0', '1', '3', '4', '5'])
	  end

	  it "orders versions array of integers, string integers, floats, and semantic versions string" do
	    versions = [3, '1', '2.3', 9, '6.5.4', '11.4.6', 5.6]
	    result = Fastlane::Actions::AppStoreBuildInfoAction.order_versions(versions)

	    expect(result).to eq(['1', '2.3', '3', '5.6', '6.5.4', '9', '11.4.6'])
	  end

	  it "returns value as string (with build number as version string)" do
	    allow(Fastlane::Actions::AppStoreBuildInfoAction).to receive(:get_build_info).and_return(latest_build_number: "1.2.3")

	    result = Fastlane::FastFile.new.parse("lane :test do
	      app_store_build_info(username: 'name@example.com', app_identifier: 'x.y.z')
	    end").runner.execute(:test)

	    expect(result).to eq(latest_build_number: "1.2.3")
	  end

	  it "returns value as integer (with build number as version number)" do
	    allow(Fastlane::Actions::AppStoreBuildInfoAction).to receive(:get_build_info).and_return(latest_build_number: "3")

	    result = Fastlane::FastFile.new.parse("lane :test do
	      app_store_build_info(username: 'name@example.com', app_identifier: 'x.y.c')
	    end").runner.execute(:test)

	    expect(result).to eq(latest_build_number: 3)
	  end

	  it "returns value as string (with version number as version string)" do
	    allow(Fastlane::Actions::AppStoreBuildInfoAction).to receive(:get_build_info).and_return(latest_version_number: "1.2.3")

	    result = Fastlane::FastFile.new.parse("lane :test do
	      app_store_build_info(username: 'name@example.com', app_identifier: 'x.y.z')
	    end").runner.execute(:test)

	    expect(result).to eq(latest_version_number: "1.2.3")
	  end
	end
end
