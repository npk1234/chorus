require 'spec_helper'

describe WorkspacesController do
  let(:owner) { FactoryGirl.create(:user)}
  before do
    log_in owner
  end

  describe "#index" do
    before do
      FactoryGirl.create(:workspace, :name => "Work", :owner => owner)
      FactoryGirl.create(:workspace, :name => "abacus", :archived_at => 2.days.ago)
      @private_workspace = FactoryGirl.create(:workspace, :public => false)
      @joined_private_workspace = FactoryGirl.create(:workspace, :public => false, :name => "secret1")
      owner.workspaces << @joined_private_workspace
    end

    it_behaves_like "an action that requires authentication", :get, :index

    it "returns all workspaces that are public or which the current user is a member of" do
      get :index
      response.code.should == "200"
      decoded_response.length.should == 3
      p decoded_response
      decoded_response.map(&:name).should include("secret1")
    end

    it "sorts by workspace name" do
      get :index
      decoded_response[0].name.should == "abacus"
      decoded_response[1].name.should == "Work"
    end

    it "scopes by active status" do
      get :index, :active => 1
      decoded_response.size.should == 1
      decoded_response[0].name.should == "Work"
    end

    it "scopes by owner" do
      get :index, :user_id => owner.id
      decoded_response.size.should == 1
      decoded_response[0].name.should == "Work"
    end

    describe "pagination" do
      before do
        FactoryGirl.create(:workspace, :name=> 'zed')
      end

      it "paginates the collection" do
        get :index, :page => 1, :per_page => 2
        decoded_response.length.should == 2
      end

      it "defaults to page one" do
        get :index, :per_page => 2
        decoded_response.length.should == 2
        decoded_response.first.name.should == "abacus"
        decoded_response.second.name.should == "Work"
      end

      it "accepts a page parameter" do
        get :index, :page => 2, :per_page => 2
        decoded_response.length.should == 1
        decoded_response.first.name.should == "zed"
      end

      it "defaults the per_page to fifty" do
        get :index
        request.params[:per_page].should == 50
      end
    end
  end

  describe "#create" do
    it_behaves_like "an action that requires authentication", :post, :create

    context "with valid parameters" do
      let(:parameters) { { :workspace => { :name => "foobar" } } }

      it "creates a workspace" do
        lambda {
          post :create, parameters
        }.should change(Workspace, :count).by(1)
      end

      it "presents the workspace" do
        post :create, parameters
        parameters[:workspace].keys.each do |key|
          decoded_response[key].should == parameters[:workspace][key]
        end
      end

      it "adds the owner as a member of the workspace" do
        post :create, parameters
        Workspace.last.memberships.first.user.should == owner
      end

      it "sets the authenticated user as the owner of the new workspace" do
        post :create, parameters
        Workspace.last.owner.should == owner
      end
    end
  end

  describe "#show" do
    let(:joe) { FactoryGirl.create(:user) }

    before do
      log_in owner
    end

    it_behaves_like "an action that requires authentication", :get, :show

    context "with a valid workspace id" do
      let(:workspace) { FactoryGirl.create(:workspace) }

      it "succeeds" do
        get :show, :id => workspace.to_param
        response.should be_success
      end

      it "presents the workspace" do
        mock.proxy(controller).present(workspace)
        get :show, :id => workspace.to_param
      end
    end

    context "with an invalid workspace id" do
      it "returns not found" do
        get :show, :id => 'bogus'
        response.should be_not_found
      end
    end

    context "of a private workspace" do
      let(:workspace) { FactoryGirl.create(:workspace, :public => false) }

      it "returns not found for a non-member" do
        log_in joe
        get :show, :id => workspace.to_param
        response.should be_not_found
      end
    end
    #it "generates a jasmine fixture", :fixture => true do
    #  get :show, :id => @other_user.to_param
    #  save_fixture "user.json"
    #end
  end
end
