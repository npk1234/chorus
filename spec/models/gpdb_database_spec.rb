require 'spec_helper'

describe GpdbDatabase do
  describe "validations" do
    it 'has a valid factory' do
      FactoryGirl.build(:gpdb_database).should be_valid
    end

    it { should validate_presence_of(:name) }

    it 'does not allow strange characters in the name' do
      new_database = FactoryGirl.build(:gpdb_database, :name => "database/name")
      new_database.should_not be_valid
      new_database.should have_error_on(:name)
    end

    describe 'name uniqueness' do
      let(:existing) { gpdb_databases(:default) }

      context 'in the same instance' do
        it 'does not allow two databases with the same name' do
          new_database = FactoryGirl.build(:gpdb_database,
                                           :name => existing.name,
                                           :gpdb_instance => existing.gpdb_instance)
          new_database.should_not be_valid
          new_database.should have_error_on(:name).with_message(:taken)
        end
      end

      context 'in a different instance' do
        it 'allows same names' do
          new_database = FactoryGirl.build(:gpdb_database, :name => existing.name)
          new_database.should be_valid
        end
      end
    end
  end

  describe '#refresh' do
    let(:gpdb_instance) { FactoryGirl.build_stubbed(:gpdb_instance) }
    let(:account) { FactoryGirl.build_stubbed(:instance_account, :gpdb_instance => gpdb_instance) }
    let(:db_names) { ["db_a", "db_B", "db_C", "db_d"] }
    let(:connection) { Object.new }

    before(:each) do
      stub(gpdb_instance).connect_with(account) { connection }
      stub(connection).databases { db_names }
    end

    it "creates new copies of the databases in our db" do
      GpdbDatabase.refresh(account)

      databases = gpdb_instance.databases

      databases.length.should == 4
      databases.map { |db| db.name }.should =~ db_names
      databases.map { |db| db.gpdb_instance_id }.uniq.should == [gpdb_instance.id]
    end

    it "returns a list of GpdbDatabase objects" do
      results = GpdbDatabase.refresh(account)

      db_objects = []
      db_names.each do |name|
        db_objects << gpdb_instance.databases.find_by_name(name)
      end

      results.should match_array(db_objects)
    end

    it "does not re-create databases that already exist in our database" do
      GpdbDatabase.refresh(account)
      expect { GpdbDatabase.refresh(account) }.not_to change(GpdbDatabase, :count)
    end

    context "when database objects are stale" do
      before do
        GpdbDatabase.all.each { |database|
          database.mark_stale!
        }
      end

      it "marks them as non-stale" do
        GpdbDatabase.refresh(account)
        account.gpdb_instance.databases.each { |database|
          database.reload.should_not be_stale
        }
      end
    end
  end

  context "refresh using a real greenplum instance", :database_integration => true do
    let(:account) { InstanceIntegration.real_gpdb_account }

    it "sorts the database by name in ASC order" do
      results = GpdbDatabase.refresh(account)
      result_names = results.map { |db| db.name.downcase.gsub(/[^0-9A-Za-z]/, '') }
      result_names.should == result_names.sort
    end
  end

  describe "reindexDatasetPermissions" do
    let(:database) { gpdb_databases(:default) }

    it "calls solr_index on all datasets" do
      database.datasets.each do |dataset|
        mock(Sunspot).index(dataset)
      end
      GpdbDatabase.reindexDatasetPermissions(database.id)
    end

    it "does not call solr_index on stale datasets" do
      dataset = database.datasets.first
      dataset.update_attributes!({:stale_at => Time.current}, :without_protection => true)
      stub(Sunspot).index(anything)
      dont_allow(Sunspot).index(dataset)
      GpdbDatabase.reindexDatasetPermissions(database.id)
    end

    it "does a solr commit" do
      mock(Sunspot).commit
      GpdbDatabase.reindexDatasetPermissions(database.id)
    end

    it "continues if exceptions are raised" do
      database.datasets.each do |dataset|
        mock(Sunspot).index(dataset) { raise "error!" }
      end
      mock(Sunspot).commit
      GpdbDatabase.reindexDatasetPermissions(database.id)
    end
  end

  context "association" do
    it { should have_many :schemas }

    it "has many datasets" do
      gpdb_databases(:default).datasets.should include(datasets(:table))
    end
  end

  describe "callbacks" do
    let(:database) { gpdb_databases(:default) }

    describe "before_save" do
      describe "#mark_schemas_as_stale" do
        it "if the database has become stale, schemas will also be marked as stale" do
          database.update_attributes!({:stale_at => Time.current}, :without_protection => true)
          schema = database.schemas.first
          schema.should be_stale
          schema.stale_at.should be_within(5.seconds).of(Time.current)
        end
      end
    end
  end

  describe ".create_schema" do
    context "using a real greenplum instance", :database_integration => true do
      let(:account) { InstanceIntegration.real_gpdb_account }
      let(:database) { GpdbDatabase.find_by_name_and_gpdb_instance_id(InstanceIntegration.database_name, InstanceIntegration.real_gpdb_instance) }
      let(:instance) { database.gpdb_instance }

      after do
        exec_on_gpdb('DROP SCHEMA IF EXISTS "my_new_schema"')
      end

      it "creates the schema" do

        database.create_schema("my_new_schema", account.owner).tap do |schema|
          schema.name.should == "my_new_schema"
          schema.database.should == database
        end

        database.schemas.find_by_name("my_new_schema").should_not be_nil

        exec_on_gpdb("select * from pg_namespace where nspname = 'my_new_schema';") do |result|
          result[0]["nspname"].should == "my_new_schema"
        end
      end

      it "raises an error if a schema with the same name already exists" do
        expect {
          database.create_schema(database.schemas.last.name, account.owner)
        }.to raise_error(ActiveRecord::StatementInvalid) { |exception|
          exception.message.should match("already exists")
        }
      end

      def exec_on_gpdb(sql)
        Gpdb::ConnectionBuilder.connect!(instance, account, database.name) do |connection|
          result = connection.exec_query(sql)
          block_given? ? yield(result) : result
        end
      end
    end

    context "when gpdb connection is broken" do
      let(:database) { gpdb_databases(:default) }
      let(:user) { users(:owner) }

      it "does not create a local database" do
        expect {
          database.create_schema("my_new_schema", user)
        }.to raise_error(GreenplumConnection::InstanceUnreachable)
        database.schemas.find_by_name("my_new_schema").should be_nil
      end
    end
  end

  describe "#connect_with" do
    let(:database) { gpdb_databases(:default) }
    let(:instance) { database.gpdb_instance }
    let(:account) { instance_accounts(:unauthorized) }

    it "should return a GreenplumConnection" do
      mock(GreenplumConnection::DatabaseConnection).new({
                                                            :host => instance.host,
                                                            :port => instance.port,
                                                            :username => account.db_username,
                                                            :password => account.db_password,
                                                            :database => database.name
      }) { "this is my connection" }
      database.connect_with(account).should == "this is my connection"
    end
  end
end
