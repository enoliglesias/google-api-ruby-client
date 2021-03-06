# Copyright 2010 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'spec_helper'

require 'json'
require 'signet/oauth_1/client'
require 'httpadapter/adapters/net_http'

require 'google/api_client'
require 'google/api_client/version'
require 'google/api_client/parsers/json_parser'

describe Google::APIClient do
  before do
    @client = Google::APIClient.new
  end

  it 'should raise a type error for bogus authorization' do
    (lambda do
      Google::APIClient.new(:authorization => 42)
    end).should raise_error(TypeError)
  end

  it 'should not be able to retrieve the discovery document for a bogus API' do
    (lambda do
      @client.discovery_document('bogus')
    end).should raise_error(Google::APIClient::TransmissionError)
    (lambda do
      @client.discovered_api('bogus')
    end).should raise_error(Google::APIClient::TransmissionError)
  end

  it 'should raise an error for bogus services' do
    (lambda do
      @client.discovered_api(42)
    end).should raise_error(TypeError)
  end

  it 'should raise an error for bogus services' do
    (lambda do
      @client.preferred_version(42)
    end).should raise_error(TypeError)
  end

  it 'should raise an error for bogus methods' do
    (lambda do
      @client.generate_request(42)
    end).should raise_error(TypeError)
  end

  it 'should not return a preferred version for bogus service names' do
    @client.preferred_version('bogus').should == nil
  end

  describe 'with the prediction API' do
    before do
      @client.authorization = nil
      # The prediction API no longer exposes a v1, so we have to be
      # careful about looking up the wrong API version.
      @prediction = @client.discovered_api('prediction', 'v1.2')
    end

    it 'should correctly determine the discovery URI' do
      @client.discovery_uri('prediction').should ===
        'https://www.googleapis.com/discovery/v1/apis/prediction/v1/rest'
    end

    it 'should correctly determine the discovery URI if :user_ip is set' do
      @client.user_ip = '127.0.0.1'
      request = @client.generate_request(
        :http_method => 'GET',
        :uri => @client.discovery_uri('prediction', 'v1.2'),
        :authenticated => false
      )
      http_method, uri, headers, body = request
      uri.should === (
        'https://www.googleapis.com/discovery/v1/apis/prediction/v1.2/rest' +
        '?userIp=127.0.0.1'
      )
    end

    it 'should correctly determine the discovery URI if :key is set' do
      @client.key = 'qwerty'
      request = @client.generate_request(
        :http_method => 'GET',
        :uri => @client.discovery_uri('prediction', 'v1.2'),
        :authenticated => false
      )
      http_method, uri, headers, body = request
      uri.should === (
        'https://www.googleapis.com/discovery/v1/apis/prediction/v1.2/rest' +
        '?key=qwerty'
      )
    end

    it 'should correctly determine the discovery URI if both are set' do
      @client.key = 'qwerty'
      @client.user_ip = '127.0.0.1'
      request = @client.generate_request(
        :http_method => 'GET',
        :uri => @client.discovery_uri('prediction', 'v1.2'),
        :authenticated => false
      )
      http_method, uri, headers, body = request
      uri.should === (
        'https://www.googleapis.com/discovery/v1/apis/prediction/v1.2/rest' +
        '?key=qwerty&userIp=127.0.0.1'
      )
    end

    it 'should correctly generate API objects' do
      @client.discovered_api('prediction', 'v1.2').name.should == 'prediction'
      @client.discovered_api('prediction', 'v1.2').version.should == 'v1.2'
      @client.discovered_api(:prediction, 'v1.2').name.should == 'prediction'
      @client.discovered_api(:prediction, 'v1.2').version.should == 'v1.2'
    end

    it 'should discover methods' do
      @client.discovered_method(
        'prediction.training.insert', 'prediction', 'v1.2'
      ).name.should == 'insert'
      @client.discovered_method(
        :'prediction.training.insert', :prediction, 'v1.2'
      ).name.should == 'insert'
      @client.discovered_method(
        'prediction.training.delete', 'prediction', 'v1.2'
      ).name.should == 'delete'
    end

    it 'should not find methods that are not in the discovery document' do
      @client.discovered_method(
        'prediction.bogus', 'prediction', 'v1.2'
      ).should == nil
    end

    it 'should raise an error for bogus methods' do
      (lambda do
        @client.discovered_method(42, 'prediction', 'v1.2')
      end).should raise_error(TypeError)
    end

    it 'should raise an error for bogus methods' do
      (lambda do
        @client.generate_request(@client.discovered_api('prediction', 'v1.2'))
      end).should raise_error(TypeError)
    end

    it 'should correctly determine the preferred version' do
      @client.preferred_version('prediction').version.should_not == 'v1'
      @client.preferred_version(:prediction).version.should_not == 'v1'
    end

    it 'should generate valid requests' do
      request = @client.generate_request(
        :api_method => @prediction.training.insert,
        :parameters => {'data' => '12345', }
      )
      method, uri, headers, body = request
      method.should == 'POST'
      uri.should ==
        'https://www.googleapis.com/prediction/v1.2/training?data=12345'
      (headers.inject({}) { |h,(k,v)| h[k]=v; h }).should == {}
      body.should respond_to(:each)
    end

    it 'should generate requests against the correct URIs' do
      request = @client.generate_request(
        :api_method => @prediction.training.insert,
        :parameters => {'data' => '12345'}
      )
      method, uri, headers, body = request
      uri.should ==
        'https://www.googleapis.com/prediction/v1.2/training?data=12345'
    end

    it 'should encode URIs with + and =' do
      request = @client.generate_request(
        :api_method => @prediction.training.insert,
        :parameters => {'pageToken' => '++bad=token+for++page='}
      )
      method, uri, headers, body = request
      uri.should ==
        'https://www.googleapis.com/prediction/v1.2/training?pageToken=%2B%2Bbad%3Dtoken%2Bfor%2B%2Bpage%3D'
    end

    it 'should allow modification to the base URIs for testing purposes' do
      prediction = @client.discovered_api('prediction', 'v1.2')
      prediction.method_base =
        'https://testing-domain.googleapis.com/prediction/v1.2/'
      request = @client.generate_request(
        :api_method => prediction.training.insert,
        :parameters => {'data' => '123'}
      )
      method, uri, headers, body = request
      uri.should == (
        'https://testing-domain.googleapis.com/' +
        'prediction/v1.2/training?data=123'
      )
    end

    it 'should generate OAuth 1 requests' do
      @client.authorization = :oauth_1
      @client.authorization.token_credential_key = '12345'
      @client.authorization.token_credential_secret = '12345'
      request = @client.generate_request(
        :api_method => @prediction.training.insert,
        :parameters => {'data' => '12345'}
      )
      method, uri, headers, body = request
      headers = headers.inject({}) { |h,(k,v)| h[k]=v; h }
      headers.keys.should include('Authorization')
      headers['Authorization'].should =~ /^OAuth/
    end

    it 'should generate OAuth 2 requests' do
      @client.authorization = :oauth_2
      @client.authorization.access_token = '12345'
      request = @client.generate_request(
        :api_method => @prediction.training.insert,
        :parameters => {'data' => '12345'}
      )
      method, uri, headers, body = request
      headers = headers.inject({}) { |h,(k,v)| h[k]=v; h }
      headers.keys.should include('Authorization')
      headers['Authorization'].should =~ /^OAuth/
    end

    it 'should not be able to execute improperly authorized requests' do
      @client.authorization = :oauth_1
      @client.authorization.token_credential_key = '12345'
      @client.authorization.token_credential_secret = '12345'
      result = @client.execute(
        @prediction.training.insert,
        {'data' => '12345'}
      )
      status, headers, body = result.response
      status.should == 401
    end

    it 'should not be able to execute improperly authorized requests' do
      @client.authorization = :oauth_2
      @client.authorization.access_token = '12345'
      result = @client.execute(
        @prediction.training.insert,
        {'data' => '12345'}
      )
      status, headers, body = result.response
      status.should == 401
    end

    it 'should not be able to execute improperly authorized requests' do
      (lambda do
        @client.authorization = :oauth_1
        @client.authorization.token_credential_key = '12345'
        @client.authorization.token_credential_secret = '12345'
        result = @client.execute!(
          @prediction.training.insert,
          {'data' => '12345'}
        )
      end).should raise_error(Google::APIClient::ClientError)
    end

    it 'should not be able to execute improperly authorized requests' do
      (lambda do
        @client.authorization = :oauth_2
        @client.authorization.access_token = '12345'
        result = @client.execute!(
          @prediction.training.insert,
          {'data' => '12345'}
        )
      end).should raise_error(Google::APIClient::ClientError)
    end

    it 'should correctly handle unnamed parameters' do
      @client.authorization = :oauth_2
      @client.authorization.access_token = '12345'
      result = @client.execute(
        @prediction.training.insert,
        {},
        JSON.generate({"id" => "bucket/object"}),
        {'Content-Type' => 'application/json'}
      )
      method, uri, headers, body = result.request
      Hash[headers]['Content-Type'].should == 'application/json'
    end
  end

  describe 'with the plus API' do
    before do
      @client.authorization = nil
      @plus = @client.discovered_api('plus')
    end

    it 'should correctly determine the discovery URI' do
      @client.discovery_uri('plus').should ===
        'https://www.googleapis.com/discovery/v1/apis/plus/v1/rest'
    end

    it 'should find APIs that are in the discovery document' do
      @client.discovered_api('plus').name.should == 'plus'
      @client.discovered_api('plus').version.should == 'v1'
      @client.discovered_api(:plus).name.should == 'plus'
      @client.discovered_api(:plus).version.should == 'v1'
    end

    it 'should find methods that are in the discovery document' do
      # TODO(bobaman) Fix this when the RPC names are correct
      @client.discovered_method(
        'plus.activities.list', 'plus'
      ).name.should == 'list'
    end

    it 'should not find methods that are not in the discovery document' do
      @client.discovered_method('plus.bogus', 'plus').should == nil
    end

    it 'should generate requests against the correct URIs' do
      request = @client.generate_request(
        :api_method => @plus.activities.list,
        :parameters => {
          'userId' => '107807692475771887386', 'collection' => 'public'
        },
        :authenticated => false
      )
      method, uri, headers, body = request
      uri.should == (
        'https://www.googleapis.com/plus/v1/' +
        'people/107807692475771887386/activities/public'
      )
    end

    it 'should correctly validate parameters' do
      (lambda do
        @client.generate_request(
          :api_method => @plus.activities.list,
          :parameters => {'alt' => 'json'},
          :authenticated => false
        )
      end).should raise_error(ArgumentError)
    end

    it 'should correctly validate parameters' do
      (lambda do
        @client.generate_request(
          :api_method => @plus.activities.list,
          :parameters => {
            'userId' => '107807692475771887386', 'collection' => 'bogus'
          },
          :authenticated => false
        )
      end).should raise_error(ArgumentError)
    end
  end

  describe 'with the analytics API' do
    before do
      @client.authorization = nil
      @analytics = @client.discovered_api('analytics', 'v3')
      @parameters = {
                      "ids" => "ga:666",
                      "start-date" => "2014-12-12",
                      "end-date" => "today",
                      "metrics" => "ga:users"
                    }
    end

    it 'should correctly determine the discovery URI' do
      @client.discovery_uri('analytics', 'v3').should ===
        'https://www.googleapis.com/discovery/v1/apis/analytics/v3/rest'
    end

    it 'should find APIs that are in the discovery document' do
      @client.discovered_api('analytics', 'v3').name.should == 'analytics'
      @client.discovered_api('analytics', 'v3').version.should == 'v3'
    end

    it 'should find methods that are in the discovery document' do
      @client.discovered_method(
        'analytics.data.ga.get', 'analytics', 'v3'
      ).name.should == 'get'
    end

    it 'should not find methods that are not in the discovery document' do
      @client.discovered_method('analytics.fake', 'analytics', 'v3').should == nil
    end

    it 'should generate requests against the correct URIs' do
      request = @client.generate_request(
        :api_method => 'analytics.data.ga.get',
        :version => 'v3',
        :authenticated => false,
        :parameters => @parameters

      )
      method, uri, headers, body = request
      uri.should ==
        'https://www.googleapis.com/analytics/v3/data/ga?end-date=today&ids=ga%3A666&metrics=ga%3Ausers&start-date=2014-12-12'
    end

    it 'should generate requests against the correct URIs' do
      request = @client.generate_request(
        :api_method => @analytics.management.accounts.list,
        :authenticated => false
      )
      method, uri, headers, body = request
      uri.should ==
        'https://www.googleapis.com/analytics/v3/management/accounts'
    end

    it 'should not be able to execute requests without authorization' do
      result = @client.execute(
        :api_method => 'analytics.data.ga.get',
        :version => 'v3',
        :authenticated => false,
        :parameters => @parameters
      )
      status, headers, body = result.response
      status.should == 401
    end
  end
end
