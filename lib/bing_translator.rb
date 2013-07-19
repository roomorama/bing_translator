#!/usr/bin/env ruby
# encoding: utf-8
# (c) 2011-present. Ricky Elrod <ricky@elrod.me>
# Released under the MIT license.
require 'rubygems'
require 'cgi'
require 'uri'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'json'

class BingTranslator
  TRANSLATE_URI = 'http://api.microsofttranslator.com/V2/Http.svc/Translate'
  TRANSLATE_ARRAY_URI = 'http://api.microsofttranslator.com/V2/Http.svc/TranslateArray'
  DETECT_URI = 'http://api.microsofttranslator.com/V2/Http.svc/Detect'
  LANG_CODE_LIST_URI = 'http://api.microsofttranslator.com/V2/Http.svc/GetLanguagesForTranslate'
  ACCESS_TOKEN_URI = 'https://datamarket.accesscontrol.windows.net/v2/OAuth2-13'
  SPEAK_URI = 'http://api.microsofttranslator.com/v2/Http.svc/Speak'

  class Exception < StandardError; end
  class AuthenticationException < StandardError; end

  attr_reader :request_type

  def initialize(client_id, client_secret, skip_ssl_verify = false)
    @client_id = client_id
    @client_secret = client_secret
    @skip_ssl_verify = skip_ssl_verify
    @access_token_uri = URI.parse(ACCESS_TOKEN_URI)

    @request_type = {
      translate: {method: :get, uri: URI.parse(TRANSLATE_URI)},
      translate_array: {method: :post, uri: URI.parse(TRANSLATE_ARRAY_URI)},
      detect: {method: :get, uri: URI.parse(DETECT_URI)},
      list_codes: {method: :get, uri: URI.parse(LANG_CODE_LIST_URI)},
      speak: {method: :get, uri: URI.parse(SPEAK_URI)} }
  end

  def translate(text, params = {})
    raise "Must provide :to." if params[:to].nil?

    from = CGI.escape params[:from].to_s
    params = {
      'to' => CGI.escape(params[:to].to_s),
      'text' => CGI.escape(text.to_s),
      'category' => 'general',
      'contentType' => 'text/plain'
    }
    params[:from] = from unless from.empty?
    result = result(:translate, params)

    Nokogiri.parse(result.body).at_xpath("//xmlns:string").content
  end

  def translate_array(text_array, params = {})
    raise "Must provide :to." if params[:to].nil?
    xml_body = translate_array_xml_builder(text_array, params)
    result = result(:translate_array, xml_body)

    Nokogiri.parse(result.body).xpath("//namespace:TranslatedText", "namespace" => "http://schemas.datacontract.org/2004/07/Microsoft.MT.Web.Service.V2").children.map { |c| c.content }
  end

  def detect(text)
    params = {
      'text' => CGI.escape(text.to_s),
      'category' => 'general',
      'contentType' => 'text/plain'
    }
    result = result(:detect, params)

    Nokogiri.parse(result.body).at_xpath("//xmlns:string").content.to_sym
  end

  # format:   'audio/wav' [default] or 'audio/mp3'
  # language: valid translator language code
  # options:  'MinSize' [default] or 'MaxQuality'
  def speak(text, params = {})
    raise "Must provide :language" if params[:language].nil?

    params = {
      'format' => CGI.escape(params[:format].to_s),
      'text' => CGI.escape(text.to_s),
      'language' => params[:language].to_s
    }

    result = result(:speak, params, { "Content-Type" => params[:format].to_s })

    result.body
  end

  def supported_language_codes
    result = result(:list_codes)
    Nokogiri.parse(result.body).xpath("//xmlns:string").map(&:content)
  end

  def prepare_param_string(params)
    params.map { |key, value| "#{key}=#{value}" }.join '&'
  end

  def result(request_type, params={}, headers={})
    uri = @request_type[request_type][:uri]
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @skip_ssl_verify
    end

    case @request_type[request_type][:method]
      when :get
        request = build_get_request(uri, params)
      when :post
        request = build_post_request(uri, params)
    end

    results = http.request(request)

    if results.response.code.to_i == 200
      results
    else
      html = Nokogiri::HTML(results.body)
      raise Exception, html.xpath("//text()").remove.map(&:to_s).join(' ')
    end
  end

  def build_get_request(uri, params)
    get_access_token
    request = Net::HTTP::Get.new("#{uri.path}?#{prepare_param_string(params)}")
    request.add_field 'Authorization', "Bearer #{@access_token['access_token']}"
    request
  end

  def build_post_request(uri, body)
    get_access_token
    request = Net::HTTP::Post.new(uri.request_uri)
    request.content_type = "text/xml"
    request.add_field 'Authorization', "Bearer #{@access_token['access_token']}"
    request.body = body
    request
  end

  def post_request(uri, xml_body)
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @skip_ssl_verify
    end

    results = http.request(build_post_request(uri, xml_body))

    if results.response.code.to_i == 200
      results
    else
      html = Nokogiri::HTML(results.body)
      raise Exception, html.xpath("//text()").remove.map(&:to_s).join(' ')
    end
  end
  # Private: Get a new access token
  #
  # Microsoft changed up how you get access to the Translate API.
  # This gets a new token if it's required. We call this internally
  # before any request we make to the Translate API.
  #
  # Returns nothing if we don't need a new token yet, or
  #   a Hash of information relating to the token if we obtained a new one.
  #   Also sets @access_token internally.
  def get_access_token
    return @access_token if @access_token and
      Time.now < @access_token['expires_at']

    params = {
      'client_id' => CGI.escape(@client_id),
      'client_secret' => CGI.escape(@client_secret),
      'scope' => CGI.escape('http://api.microsofttranslator.com'),
      'grant_type' => 'client_credentials'
    }

    http = Net::HTTP.new(@access_token_uri.host, @access_token_uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @skip_ssl_verify

    response = http.post(@access_token_uri.path, prepare_param_string(params))
    @access_token = JSON.parse(response.body)
    raise AuthenticationException, @access_token['error'] if @access_token["error"]
    @access_token['expires_at'] = Time.now + @access_token['expires_in'].to_i
    @access_token
  end

  def translate_array_xml_builder(text_array, params = {})
    data_contract = "http://schemas.datacontract.org/2004/07/Microsoft.MT.Web.Service.V2"
    serialization = "http://schemas.microsoft.com/2003/10/Serialization/Arrays"
    Nokogiri::XML::Builder.new do |xml|
      xml.TranslateArrayRequest {
        xml.AppId
        xml.From_ params[:from]
        xml.Options {
          xml.Category({xmlns: data_contract}, "general")
          xml.ContentType({xmlns: data_contract}, "text/plain")
          xml.ReservedFlags({xmlns: data_contract})
          xml.State({xmlns: data_contract})
          xml.Uri({xmlns: data_contract})
          xml.User({xmlns: data_contract})
        }
        xml.Texts {
          text_array.each do |text|
            xml.string({xmlns: serialization}, text)
          end
        }
        xml.To_ params[:to]
      }
    end.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION).strip
  end
end