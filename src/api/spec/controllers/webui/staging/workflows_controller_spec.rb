require 'rails_helper'

RSpec.describe Webui::Staging::WorkflowsController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:managers_group) { create(:group) }
  let(:other_managers_group) { create(:group) }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow, project: project, managers_group: managers_group) }

  before do
    login(user)
  end

  describe 'GET #new' do
    context 'non existent staging_workflow for project' do
      before do
        get :new, params: { project: project.name }
      end

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(assigns[:staging_workflow].class).to be(Staging::Workflow) }
      it { expect(response).to render_template(:new) }
    end

    context 'with an existent staging_workflow for project' do
      before do
        staging_workflow
        get :new, params: { project: project.name }
      end

      it { expect(Staging::Workflow.count).to eq(1) }
      it { expect(response).to redirect_to(staging_workflow_path(project.staging)) }
    end
  end

  describe 'POST #create' do
    context 'a staging_workflow and staging_projects' do
      before do
        post :create, params: { project: project.name, managers_title: managers_group.title }
      end

      subject { project.staging }

      it { expect(Staging::Workflow.count).to eq(1) }
      it { expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:A', 'home:tom:Staging:B']) }
      it { expect(response).to redirect_to(staging_workflow_path(project.staging)) }
      it { expect(subject.managers_group).to eq(managers_group) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with existent stagings projects' do
      let!(:staging_a) { create(:project, name: "#{project}:Staging:A") }
      let!(:staging_b) { create(:project, name: "#{project}:Staging:B") }

      before do
        post :create, params: { project: project.name, managers_title: managers_group.title }
      end

      subject { project.staging }

      it { expect(Staging::Workflow.count).to eq(1) }
      it { expect(subject.staging_projects.map(&:name)).to match_array(['home:tom:Staging:A', 'home:tom:Staging:B']) }
      it { expect(response).to redirect_to(staging_workflow_path(project.staging)) }
      it { expect(subject.managers_group).to eq(managers_group) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'when it cannot find the managers group' do
      let(:params) { { project_name: project.name, managers_title: 'ItDoesNotExist' } }

      before do
        post :create, params: params
      end

      it { expect(response).to redirect_to(new_staging_workflow_path(project_name: project))  }
      it { expect(flash[:error]).to eq("Managers Group #{params[:managers_title]} couldn't be found") }
    end

    context 'when it fails to save the staging workflow' do
      before do
        allow_any_instance_of(Staging::Workflow).to receive(:save).and_return(false)
        post :create, params: { project: project.name, managers_title: managers_group.title }
      end

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(response).to redirect_to(new_staging_workflow_path(project_name: project)) }
      it { expect(flash[:error]).to eq("Staging for #{project} couldn't be created") }
    end
  end

  describe 'GET #show' do
    context 'non existent staging_workflow for project' do
      before do
        get :show, params: { id: 5 }
      end

      it { expect(assigns[:staging_workflow]).to be_nil }
      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an existent staging_workflow for project' do
      before do
        staging_workflow
        get :show, params: { id: project.staging }
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(assigns[:project]).to eq(project) }
      it { expect(response).to render_template(:show) }
    end
  end

  describe 'GET #edit' do
    context 'non existent staging_workflow for project' do
      before do
        get :edit, params: { id: 5 }
      end

      it { expect(assigns[:staging_workflow]).to be_nil }
      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an existent staging_workflow for project' do
      before do
        staging_workflow
        get :edit, params: { id: project.staging }
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(assigns[:project]).to eq(project) }
      it { expect(response).to render_template(:edit) }
    end
  end

  describe 'DELETE #destroy' do
    let!(:staging_workflow) { create(:staging_workflow, project: project) }

    context 'a staging workflow and staging projects' do
      before do
        params = { id: project.staging, staging_project_ids: project.staging.staging_projects.ids, format: :js }
        delete :destroy, params: params
      end

      subject { project.staging }

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(subject.staging_projects.count).to eq(0) }
      it { expect(flash[:success]).not_to be_nil }
      it { expect(response.body).to eq("window.location='#{project_show_path(project)}'") }
      it { expect(project.subprojects.count).to eq(0) }
    end

    context 'a staging workflow and one staging project' do
      before do
        params = { id: project.staging, staging_project_ids: project.staging.staging_projects.ids.first, format: :js }
        delete :destroy, params: params
      end

      subject { project.staging }

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(subject.staging_projects.count).to eq(0) }
      it { expect(project.subprojects.count).to eq(1) }
      it { expect(flash[:success]).not_to be_nil }
      it { expect(response.body).to eq("window.location='#{project_show_path(project)}'") }
    end

    context 'a staging workflow unsuccessful' do
      before do
        allow_any_instance_of(Staging::Workflow).to receive(:destroy).and_return(false)
        params = { id: project.staging, staging_project_ids: project.staging.staging_projects.ids, format: :js }
        delete :destroy, params: params
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response.body).to eq("window.location='#{staging_workflow_path(project.staging)}'") }
    end
  end

  describe 'PUT #update' do
    context 'without any problem' do
      before do
        put :update, params: { id: staging_workflow, managers_title: other_managers_group.title }
      end

      subject { staging_workflow.reload }

      it { expect(subject.managers_group).to eq(other_managers_group) }

      it 'assigns the new group and unassigns the old one' do
        subject.staging_projects.each do |staging_project|
          expect(staging_project.groups).to contain_exactly(other_managers_group)
        end
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with a failing save for staging workflow' do
      before do
        staging_workflow
        allow_any_instance_of(Staging::Workflow).to receive(:save).and_return(false)
        put :update, params: { id: staging_workflow, managers_title: other_managers_group.title }
      end

      subject { staging_workflow.reload }

      it { expect(subject.managers_group).to eq(managers_group) }

      it 'don\'t assigns the new group and unassigns the old one' do
        subject.staging_projects.each do |staging_project|
          expect(staging_project.groups).to contain_exactly(managers_group)
        end
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject)) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end
end
