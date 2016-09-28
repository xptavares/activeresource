require 'abstract_unit'
require "fixtures/person"
require "fixtures/street_address"

class FormatTest < ActiveSupport::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }
    @david = { :id => 2, :name => 'David' }

    @programmers = [ @matz, @david ]
  end

  def test_http_format_header_name
    [:get, :head].each do |verb|
      header_name = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES[verb]
      assert_equal 'Accept', header_name
    end

    [:patch, :put, :post].each do |verb|
      header_name = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES[verb]
      assert_equal 'Content-Type', header_name
    end
  end

  def test_formats_on_single_element
    [ :json, :xml, :json_api ].each do |format_sym|
      format = ActiveResource::Formats[format_sym]
      using_format(Person, format_sym) do
        ActiveResource::HttpMock.respond_to.get "/people/1.#{format.extension}", {'Accept' => format.mime_type}, format.encode(@david)
        assert_equal @david[:name], Person.find(1).name
      end
    end
  end

  def test_formats_on_collection
    [ :json, :xml, :json_api ].each do |format_sym|
      format = ActiveResource::Formats[format_sym]
      using_format(Person, format_sym) do
        ActiveResource::HttpMock.respond_to.get "/people.#{format.extension}", {'Accept' => format.mime_type}, format.encode(@programmers)
        remote_programmers = Person.find(:all)
        assert_equal 2, remote_programmers.size
        assert remote_programmers.find { |p| p.name == 'David' }
      end
    end
  end

  def test_formats_on_custom_collection_method
    [ :json, :xml, :json_api ].each do |format_sym|
      format = ActiveResource::Formats[format_sym]
      using_format(Person, format_sym) do
        ActiveResource::HttpMock.respond_to.get "/people/retrieve.#{format.extension}?name=David", {'Accept' => format.mime_type}, format.encode([@david])
        remote_programmers = Person.get(:retrieve, :name => 'David')
        assert_equal 1, remote_programmers.size
        assert_equal @david[:id], remote_programmers[0]['id']
        assert_equal @david[:name], remote_programmers[0]['name']
      end
    end
  end

  def test_formats_on_custom_element_method
    [:json, :xml, :json_api].each do |format_sym|
      format = ActiveResource::Formats[format_sym]
      using_format(Person, format_sym) do
        david = (format_sym == :json ? { :person => @david } : @david)
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/people/2.#{format.extension}", { 'Accept' => format.mime_type }, format.encode(david)
          mock.get "/people/2/shallow.#{format.extension}", { 'Accept' => format.mime_type }, format.encode(david)
        end
        remote_programmer = Person.find(2).get(:shallow)
        remote_id = remote_programmer['id']
        remote_name = remote_programmer['name']
        if format_sym == :json_api
          remote_id = remote_programmer['attributes']['id']
          remote_name = remote_programmer['attributes']['name']
        end
        assert_equal @david[:id], remote_id
        assert_equal @david[:name], remote_name
      end

      ryan_hash = { :name => 'Ryan' }
      ryan_hash = (format_sym == :json ? { :person => ryan_hash } : ryan_hash)
      ryan = format.encode(ryan_hash)
      using_format(Person, format_sym) do
        remote_ryan = Person.new(:name => 'Ryan')
        ActiveResource::HttpMock.respond_to.post "/people.#{format.extension}", { 'Content-Type' => format.mime_type}, ryan, 201, { 'Location' => "/people/5.#{format.extension}" }
        remote_ryan.save

        remote_ryan = Person.new(:name => 'Ryan')
        ActiveResource::HttpMock.respond_to.post "/people/new/register.#{format.extension}", { 'Content-Type' => format.mime_type}, ryan, 201, { 'Location' => "/people/5.#{format.extension}" }
        assert_equal ActiveResource::Response.new(ryan, 201, { 'Location' => "/people/5.#{format.extension}" }), remote_ryan.post(:register)
      end
    end
  end

  def test_setting_format_before_site
    resource = Class.new(ActiveResource::Base)
    resource.format = :json
    resource.site   = 'http://37s.sunrise.i:3000'
    assert_equal ActiveResource::Formats[:json], resource.connection.format
  end

  def test_serialization_of_nested_resource
    address  = { :street => '12345 Street' }
    person  = { :name => 'Rus', :address => address}

    [:json, :xml].each do |format|
      encoded_person = ActiveResource::Formats[format].encode(person)
      assert_match(/12345 Street/, encoded_person)
      remote_person = Person.new(person.update({:address => StreetAddress.new(address)}))
      assert_kind_of StreetAddress, remote_person.address
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.post "/people.#{format}", {'Content-Type' => ActiveResource::Formats[format].mime_type}, encoded_person, 201, {'Location' => "/people/5.#{format}"}
        remote_person.save
      end
    end
  end

  private
    def using_format(klass, mime_type_reference)
      previous_format = klass.format
      klass.format = mime_type_reference

      yield
    ensure
      klass.format = previous_format
    end
end
