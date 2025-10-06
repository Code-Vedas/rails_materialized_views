# frozen_string_literal: true

# Copyright Codevedas Inc. 2025-present
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

RSpec.describe 'Definitions - MV operations', :feature do
  before { visit_dashboard }

  feature 'MV operations' do
    context 'when MV is not present', :js do
      scenario 'shows create options in the Actions menu', :js do
        defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')
        visit_dashboard
        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='delete_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
        end
      end

      scenario 'clicking create MV creates the materialised view', :js do
        defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')

        visit_dashboard
        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
          find("button[data-testid='create_mv_link-defn-#{defn.id}']").click
        end

        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='refresh_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
        end
      end
    end

    context 'when MV is present', :js do
      scenario 'shows refresh and drop options in the Actions menu', :js do
        defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')

        visit_dashboard
        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='delete_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
          find("button[data-testid='create_mv_link-defn-#{defn.id}']").click
        end

        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='refresh_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
        end
      end

      scenario 'clicking refresh refreshes the materialised view', :js do
        defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')

        visit_dashboard
        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='delete_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
          find("button[data-testid='create_mv_link-defn-#{defn.id}']").click
        end

        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='refresh_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
          find("button[data-testid='refresh_link-defn-#{defn.id}']").click
        end

        wait_for_turbo_idle

        within_turbo_frame('dash-definitions') do
          expect(page).to have_css("button[data-testid='refresh_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
          expect(page).to have_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
        end

        run = MatViews::MatViewRun.where(mat_view_definition: defn).order(created_at: :desc).first
        expect(run).not_to be_nil
        expect(run.status).to eq('success')
      end

      context 'when dropping the MV', :js do
        context 'when there are no dependent objects', :js do
          scenario 'clicking drop drops the materialised view', :js do
            defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')

            visit_dashboard
            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='delete_link-defn-#{defn.id}']")
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
              find("button[data-testid='create_mv_link-defn-#{defn.id}']").click
            end

            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='refresh_link-defn-#{defn.id}']")
              expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
              expect(page).to have_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
              find("button[data-testid='drop_link-defn-#{defn.id}']").click
            end

            accept_mv_confirm
            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
              expect(page).to have_no_css("button[data-testid='refresh_link-defn-#{defn.id}']")
              expect(page).to have_no_css("button[data-testid='drop_link-defn-#{defn.id}']")
              expect(page).to have_no_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
            end
          end
        end

        context 'when there are dependent objects', :js do
          scenario 'clicking drop mv does not drop the materialised view', :js do
            defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')
            dependent_defn = create(:mat_view_definition, name: "zdependent_mv_#{uniq_token}", sql: "SELECT 1 FROM #{defn.name}")

            visit_dashboard
            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
              find("button[data-testid='create_mv_link-defn-#{defn.id}']").click
            end

            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{dependent_defn.id}']")
              find("button[data-testid='create_mv_link-defn-#{dependent_defn.id}']").click
            end

            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
              find("button[data-testid='drop_link-defn-#{defn.id}']").click
            end

            accept_mv_confirm
            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='refresh_link-defn-#{defn.id}']")
              expect(page).to have_css("button[data-testid='drop_link-defn-#{defn.id}']")
            end

            run = MatViews::MatViewRun.where(mat_view_definition: defn).order(created_at: :desc).first
            expect(run).not_to be_nil
            expect(run.status).to eq('failed')
            expect(run.error['message']).to match(/cannot drop materialized view .* because other objects depend on it/)
          end

          scenario 'clicking drop cascade drops the materialised view and dependents', :js do
            defn = create(:mat_view_definition, name: "sales_mv_#{uniq_token}", sql: 'SELECT 1 AS id')
            dependent_defn = create(:mat_view_definition, name: "zdependent_mv_#{uniq_token}", sql: "SELECT 1 FROM #{defn.name}")

            visit_dashboard
            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
              find("button[data-testid='create_mv_link-defn-#{defn.id}']").click
            end

            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{dependent_defn.id}']")
              find("button[data-testid='create_mv_link-defn-#{dependent_defn.id}']").click
            end

            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='drop_cascade_link-defn-#{defn.id}']")
              find("button[data-testid='drop_cascade_link-defn-#{defn.id}']").click
            end

            accept_mv_confirm
            wait_for_turbo_idle

            within_turbo_frame('dash-definitions') do
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{defn.id}']")
              expect(page).to have_css("button[data-testid='create_mv_link-defn-#{dependent_defn.id}']")
            end
          end
        end
      end
    end
  end
end
