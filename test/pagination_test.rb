require File.dirname(__FILE__) + '/helper'
require File.dirname(__FILE__) + '/lib/activerecord_test_case'
require 'action_controller'
require 'action_controller/test_process'

require 'will_paginate'
WillPaginate.enable

ActionController::Routing::Routes.reload rescue nil
ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

ActionController::Base.perform_caching = false

class PaginationTest < ActiveRecordTestCase
  fixtures :users
  
  class PaginationController < ActionController::Base
    def list_developers
      @developers = Developer.paginate :page => params[params[:param_name] || :page],
                                       :per_page => (params[:per_page] || 4).to_i

      @options = params.except(:count, :order)
      WillPaginate::ViewHelpers.pagination_options.keys.each { |key| params.delete key }

      render :inline => '<%= will_paginate @developers, @options %>'
    end

    def no_pagination
      @developers = Developer.paginate :page => params[:page], :per_page => 15
      render :inline => '<%= will_paginate @developers %>'
    end

  protected
    def rescue_errors(e) raise e end
    def rescue_action(e) raise e end
  end
  
  def setup
    @controller = PaginationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    super
  end

  def test_will_paginate
    get :list_developers

    entries = assigns :developers
    assert entries
    assert_equal 4, entries.size

    assert_select 'div.pagination', 1, 'no main DIV' do |el|
      assert_select 'a[href]', 3 do |elements|
        validate_page_numbers [2,3,2], elements
        assert_select elements.last, ':last-child', "Next &raquo;"
      end
      assert_select 'span', 2
      assert_select 'span.disabled:first-child', "&laquo; Previous"
      assert_select 'span.current', entries.current_page.to_s
    end
  end

  def test_will_paginate_with_options
    get :list_developers, :page => 2, :class => 'will_paginate', :prev_label => 'Prev', :next_label => 'Next'
    assert_response :success
    
    entries = assigns :developers
    assert entries
    assert_equal 4, entries.size

    assert_select 'div.will_paginate', 1, 'no main DIV' do
      assert_select 'a[href]', 4 do |elements|
        validate_page_numbers [nil,nil,3,3], elements
        assert_select elements.first, 'a', "Prev"
        assert_select elements.last, 'a', "Next"
      end
      assert_select 'span.current', entries.current_page.to_s
    end
  end
  
  def test_will_paginate_preserves_parameters
    get :list_developers, :foo => { :bar => 'baz' }
    assert_response :success
    
    assert_select 'div.pagination', 1, 'no main DIV' do
      assert_select 'a[href]', 3 do |elements|
        elements.each do |el|
          assert_match /foo%5Bbar%5D=baz/, el['href'], "THIS IS A BUG in Rails 1.2 which " +
            "has been fixed in Rails 2.0."
          # there is no need to worry *unless* you too are using hashes is parameters which
          # need to be preserved over pages
        end
      end
    end
  end
  
  def test_will_paginate_with_custom_page_param
    get :list_developers, :developers_page => 2, :param_name => :developers_page
    assert_response :success
    
    entries = assigns :developers
    assert entries
    assert_equal 4, entries.size

    assert_select 'div.pagination', 1, 'no main DIV' do
      assert_select 'a[href]', 4 do |elements|
        validate_page_numbers [nil,nil,3,3], elements, :developers_page
      end
      assert_select 'span.current', entries.current_page.to_s
    end    
  end

  def test_will_paginate_windows
    get :list_developers, :page => 6, :per_page => 1, :inner_window => 2
    assert_response :success
    
    entries = assigns :developers
    assert entries
    assert_equal 1, entries.size

    assert_select 'div.pagination', 1, 'no main DIV' do
      assert_select 'a[href]', 10 do |elements|
        validate_page_numbers [5,nil,2,4,5,7,8,10,11,7], elements
        assert_select elements.first, 'a', "&laquo; Previous"
        assert_select elements.last, 'a', "Next &raquo;"
      end
      assert_select 'span.current', entries.current_page.to_s
    end
  end

  def test_no_pagination
    get :no_pagination
    entries = assigns :developers
    assert_equal 1, entries.page_count
    assert_equal Developer.count, entries.size

    assert_select 'div', false
    assert_equal '', @response.body
  end
  
protected

  def validate_page_numbers expected, links, param_name = :page
    assert_equal(expected, links.map { |e|
      e['href'] =~ /\W#{param_name}=([^&]*)/
      $1 ? $1.to_i : $1
    })
  end
end
