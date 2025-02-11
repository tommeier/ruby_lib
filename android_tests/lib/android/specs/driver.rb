# frozen_string_literal: true

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# rake "android[driver]"
describe 'driver' do
  def sauce?
    ENV['UPLOAD_FILE'] && ENV['SAUCE_USERNAME']
  end

  t 'load_settings' do
    appium_txt = File.join(Dir.pwd, 'appium.txt')
    parsed   = Appium.load_settings file: appium_txt, verbose: true
    apk_name = File.basename parsed[:caps][:app]
    assert_equal apk_name, 'api.apk'
  end

  describe 'Appium::Driver attributes' do
    t 'no_wait' do
      no_wait
      proc { button('zz') }.must_raise Selenium::WebDriver::Error::NoSuchElementError
      set_wait
    end

    # attr_reader :default_wait, :app_path, :app_name,
    #            :app_package, :app_activity, :app_wait_activity,
    #            :sauce_username, :sauce_access_key, :port, :os, :debug
    t 'default_wait attr' do
      set_wait 1
      default_wait.must_equal 1
      set_wait # restore default
    end

    t 'app_path attr' do
      apk_name = File.basename driver_attributes[:caps][:app]
      apk_name.must_equal 'api.apk'
    end

    t 'verify all attributes' do
      actual = driver_attributes
      expected_app = File.absolute_path('../test_apps/api.apk')

      expected = {
        automation_name:     :uiautomator2,
        custom_url:          'http://127.0.0.1:4723/wd/hub',
        export_session:      false,
        export_session_path: '/tmp/appium_lib_session',
        default_wait:        1,
        sauce_username:      nil,
        sauce_access_key:    nil,
        sauce_endpoint:      'ondemand.saucelabs.com:443/wd/hub',
        port:                4723,
        device:              :android,
        debug:               true,
        listener:            nil,
        wait_timeout:        30, # default
        wait_interval:       0.5 # default
      }

      # actual[:caps].to_json send to Appium server
      caps_with_json = JSON.parse(actual[:caps].to_json)
      caps_with_json['platformName'].must_equal 'android'
      caps_with_json['app'].must_equal expected_app
      caps_with_json['appPackage'].must_equal 'io.appium.android.apis'
      caps_with_json['appActivity'].must_equal 'io.appium.android.apis.ApiDemos'
      caps_with_json['deviceName'].must_equal 'Android emulator'
      caps_with_json['someCapability'].must_equal 'some_capability'

      actual[:caps][:platformName].must_equal 'android'
      actual[:caps][:app].must_equal expected_app
      actual[:caps][:appPackage].must_equal 'io.appium.android.apis'
      actual[:caps][:appActivity].must_equal 'io.appium.android.apis.ApiDemos'
      actual[:caps][:deviceName].must_equal 'Nexus 7'
      actual[:caps][:some_capability].must_equal 'some_capability'

      dup_actual = actual.dup
      dup_actual.delete(:caps)

      raise "\n\nactual:\n\n: #{dup_actual}expected:\n\n#{expected}" if dup_actual != expected
    end
  end

  describe 'Appium::Driver' do
    t '$driver.class' do
      $driver.class.must_equal Appium::Driver
    end

    t 'absolute_app_path' do
      def absolute_app_path(path)
        $driver.class.absolute_app_path(caps: { app: path })
      end

      def validate_path(path)
        absolute_app_path(path).must_equal path
      end

      validate_path 'sauce-storage:some_storage_suffix'
      validate_path 'http://www.saucelabs.com'

      # fake real paths for osx/windows.
      FakeFS.activate!

      osx_existing_path = '/Users/user/myapp.app'
      FileUtils.mkdir_p osx_existing_path
      validate_path osx_existing_path

      # TODO: FakeFS fails on Windows paths due to the drive letters.
      # Look into how opscode/chef tests this.
      # windows_existing_path = "C:\\Program Files\\myapp.apk"
      # FileUtils.mkdir_p windows_existing_path
      # validate_path windows_existing_path

      FakeFS.deactivate!

      # bundle id test
      validate_path 'my.bundle.id'

      # relative path test

      relative_path = File.join __FILE__, ('..' + File::SEPARATOR) * 5, 'test_apps/api.apk'
      expected_path = File.expand_path relative_path

      absolute_app_path(relative_path).must_equal expected_path

      # invalid path test
      absolute_app_path('../../does_not_exist.apk').must_equal '../../does_not_exist.apk'
    end
  end

  describe 'methods' do
    t 'status' do
      appium_server_version['build'].keys.sort.include? 'version'
    end

    t 'server_version' do
      server_version = appium_server_version['build']['version']
      if sauce?
        server_version.must_match 'Sauce OnDemand'
      else
        server_version.must_match(/(\d+)\.(\d+).(\d+)/)
      end
    end

    t 'client_version' do
      client_version = appium_client_version
      expected = { version: ::Appium::VERSION }
      client_version.must_equal expected
    end

    t 'restart' do
      set_wait 1 # ensure wait is 1 before we restart.
      restart
      current_activity.must_equal '.ApiDemos'
    end

    t 'driver' do
      driver.browser.must_equal('unknown')
    end

    # Skip:
    #   screenshot   # this is slow and already tested by Appium
    #   driver_quit  # tested by restart
    #   start_driver # tested by restart
    #   no_wait  # posts value to server, it's not stored locally
    #   set_wait # posts value to server, it's not stored locally
    #   execute_script # 'mobile: ' is deprecated and plain execute_script unsupported

    t 'default_wait' do
      set_wait 1
      default_wait.must_equal 1
    end

    # returns true unless an error is raised
    t 'exists' do
      exists(0, 0) { true }.must_equal true
      exists(0, 0) { raise 'error' }.must_equal false
    end

    # any elements
    t 'find_elements' do
      wait do
        find_elements(:class_name, 'android.widget.TextView').length.must_equal 13
      end
    end

    # any element
    t 'find_element' do
      wait do
        find_element(:class_name, 'android.widget.TextView').class.must_equal ::Appium::Core::Element
      end
    end

    # simple integration sanity test to check for unexpected exceptions
    t 'set_location' do
      set_location latitude: 55, longitude: -72, altitude: 33
    rescue Selenium::WebDriver::Error::UnknownError => e
      # on android this method is expected to raise with this message when running
      # on a regular device, or on genymotion.
      # error could be many messages, including:
      # ERROR running Appium command: port should be a number or string
      # ERROR running Appium command: port should be > 0 and < 65536
      raise unless e.message.include?('ERROR running Appium command: port should be')
    end

    # settings
    t 'get settings' do
      get_settings.wont_be_nil
    end

    t 'update settings' do
      update_settings allowInvisibleElements: true
      get_settings['allowInvisibleElements'].must_equal true
    end

    # Skip: x # x is only used in Pry
  end
end
