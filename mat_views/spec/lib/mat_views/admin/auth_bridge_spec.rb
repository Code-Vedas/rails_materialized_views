# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe MatViews::Admin::AuthBridge do
  let(:base_controller) do
    Class.new do
      class << self
        attr_reader :_before_actions, :_helper_methods

        def before_action(*args, &blk)
          (@_before_actions ||= []) << (args.empty? ? :block : args)
          blk
        end

        def helper_method(*syms)
          (@_helper_methods ||= []).concat(syms)
        end
      end
    end
  end

  def build_controller
    Class.new(base_controller) do
      include MatViews::Admin::AuthBridge
    end
  end

  describe 'inclusion effects (filters & helpers)' do
    it 'registers before_action :authenticate_mat_views! and helper methods' do
      ctrl = build_controller
      expect(ctrl._before_actions).to include([:authenticate_mat_views!])
      expect(ctrl._helper_methods).to include(:mat_views_current_user, :user)
    end
  end

  describe '#user alias' do
    it 'returns the same object as #mat_views_current_user' do
      ctrl = build_controller
      inst = ctrl.new
      expect(inst.user.email).to eq(inst.mat_views_current_user.email)
    end
  end

  context 'when no host auth module is present (defaults apply)' do
    before do
      hide_const('MatViewsAdmin') if Object.const_defined?('MatViewsAdmin')
      hide_const('MatViews::Admin::HostAuth') if MatViews::Admin.const_defined?(:HostAuth)
    end

    it 'uses DefaultAuth implementation' do
      ctrl = build_controller
      inst = ctrl.new
      expect(inst.mat_views_current_user.to_s).to eq('sample-user@example.com')
    end
  end

  context 'when top-level ::MatViewsAdmin is present' do
    let(:host_mod) do
      Module.new.tap do |m|
        m.module_eval <<~RUBY, __FILE__, __LINE__ + 1
          def authenticate_mat_views!; :host_auth; end
          def authorize_mat_views!(*); :host_authorize; end
          def mat_views_current_user; :host_user; end
        RUBY
      end
    end

    before do
      stub_const('MatViewsAdmin', host_mod)
      hide_const('MatViews::Admin::HostAuth') if MatViews::Admin.const_defined?(:HostAuth)
    end

    it 'overrides DefaultAuth methods' do
      ctrl = build_controller
      inst = ctrl.new
      expect(inst.mat_views_current_user).to eq(:host_user)
      expect(inst.user).to eq(:host_user)
      expect(inst.authenticate_mat_views!).to eq(:host_auth)
      expect(inst.authorize_mat_views!(:read, :anything)).to eq(:host_authorize)
    end
  end

  context 'when namespaced ::MatViews::Admin::HostAuth is present' do
    let(:namespaced_host_mod) do
      Module.new.tap do |m|
        m.module_eval <<~RUBY, __FILE__, __LINE__ + 1
          def authenticate_mat_views!; :ns_host_auth; end
          def authorize_mat_views!(*); :ns_host_authorize; end
          def mat_views_current_user; :ns_host_user; end
        RUBY
      end
    end

    before do
      hide_const('MatViewsAdmin') if Object.const_defined?('MatViewsAdmin')
      stub_const('MatViews::Admin::HostAuth', namespaced_host_mod)
    end

    it 'overrides DefaultAuth methods' do
      ctrl = build_controller
      inst = ctrl.new
      expect(inst.mat_views_current_user).to eq(:ns_host_user)
      expect(inst.user).to eq(:ns_host_user)
      expect(inst.authenticate_mat_views!).to eq(:ns_host_auth)
      expect(inst.authorize_mat_views!(:read, :anything)).to eq(:ns_host_authorize)
    end
  end

  context 'when BOTH ::MatViewsAdmin and ::MatViews::Admin::HostAuth are present' do
    let(:top_host) do
      Module.new.tap do |m|
        m.module_eval <<~RUBY, __FILE__, __LINE__ + 1
          def mat_views_current_user; :top_host_user; end
        RUBY
      end
    end

    let(:ns_host) do
      Module.new.tap do |m|
        m.module_eval <<~RUBY, __FILE__, __LINE__ + 1
          def mat_views_current_user; :ns_host_user; end
        RUBY
      end
    end

    before do
      stub_const('MatViewsAdmin', top_host)
      stub_const('MatViews::Admin::HostAuth', ns_host)
    end

    it 'prefers the top-level ::MatViewsAdmin (per lookup order)' do
      ctrl = build_controller
      inst = ctrl.new
      expect(inst.mat_views_current_user).to eq(:top_host_user)
    end
  end
end
