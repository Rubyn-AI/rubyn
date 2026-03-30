# frozen_string_literal: true

RSpec.describe "Tool file security" do
  let(:tmpdir) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(tmpdir, "app/models"))
    FileUtils.mkdir_p(File.join(tmpdir, "config/credentials"))
    File.write(File.join(tmpdir, "app/models/user.rb"), "class User; end")
    File.write(File.join(tmpdir, "config/master.key"), "super_secret_key_123")
    File.write(File.join(tmpdir, "config/credentials.yml.enc"), "encrypted_stuff")
    File.write(File.join(tmpdir, "config/credentials/production.yml.enc"), "prod_encrypted")
    File.write(File.join(tmpdir, ".env"), "SECRET_KEY=abc123")
    File.write(File.join(tmpdir, ".env.production"), "PROD_SECRET=xyz")
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "blocked files" do
    it "blocks read_file on config/master.key" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "config/master.key" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end

    it "blocks read_file on config/credentials.yml.enc" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "config/credentials.yml.enc" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end

    it "blocks read_file on config/credentials subdirectory" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "config/credentials/production.yml.enc" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end

    it "blocks write_file on config/master.key" do
      tool = Rubyn::Tools::WriteFile.new(tmpdir)
      result = tool.call({ "path" => "config/master.key", "content" => "hacked" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end

    it "blocks path traversal to master.key" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "app/../config/master.key" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end

    it "allows reading normal files" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "app/models/user.rb" })

      expect(result[:success]).to be true
      expect(result[:content]).to include("class User")
    end
  end

  describe "sensitive files" do
    it "returns sensitive_file error for .env" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => ".env" })

      expect(result[:success]).to be false
      expect(result[:error]).to start_with("sensitive_file:")
    end

    it "allows .env read when skip_sensitive_check is true" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => ".env", "skip_sensitive_check" => true })

      expect(result[:success]).to be true
      expect(result[:content]).to include("SECRET_KEY")
    end
  end

  describe "find_files excludes blocked files" do
    it "does not list config/master.key in results" do
      tool = Rubyn::Tools::FindFiles.new(tmpdir)
      result = tool.call({ "pattern" => "config/**/*" })

      expect(result[:success]).to be true
      expect(result[:files]).not_to include("config/master.key")
      expect(result[:files]).not_to include("config/credentials.yml.enc")
      expect(result[:files]).not_to include("config/credentials/production.yml.enc")
    end
  end

  describe "search_files skips blocked and sensitive files" do
    it "does not return matches from blocked files" do
      tool = Rubyn::Tools::SearchFiles.new(tmpdir)
      result = tool.call({ "pattern" => "secret", "path" => "." })

      expect(result[:success]).to be true
      paths = result[:matches].map { |m| m[:file] }
      expect(paths).not_to include("config/master.key")
      expect(paths).not_to include(".env")
    end
  end

  describe "custom security config" do
    before do
      FileUtils.mkdir_p(File.join(tmpdir, ".rubyn"))
      File.write(File.join(tmpdir, ".rubyn", "security.yml"), YAML.dump({
        "blocked_files" => %w[config/secrets.yml],
        "sensitive_files" => %w[config/database.yml]
      }))
      File.write(File.join(tmpdir, "config/secrets.yml"), "secret: stuff")
      File.write(File.join(tmpdir, "config/database.yml"), "db: postgres")
    end

    it "blocks files from custom config" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "config/secrets.yml" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end

    it "marks files from custom config as sensitive" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "config/database.yml" })

      expect(result[:success]).to be false
      expect(result[:error]).to start_with("sensitive_file:")
    end

    it "still blocks default files even with custom config" do
      tool = Rubyn::Tools::ReadFile.new(tmpdir)
      result = tool.call({ "path" => "config/master.key" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end
  end

  describe "executor handles sensitive file confirmation" do
    it "prompts user for sensitive files and denies on 'n'" do
      allow($stdin).to receive(:gets).and_return("n\n")
      executor = Rubyn::Tools::Executor.new(tmpdir)
      result = executor.execute("read_file", { "path" => ".env" })

      expect(result[:success]).to be false
      expect(result[:error]).to eq("denied_by_user")
    end

    it "prompts user for sensitive files and allows on 'y'" do
      allow($stdin).to receive(:gets).and_return("y\n")
      executor = Rubyn::Tools::Executor.new(tmpdir)
      result = executor.execute("read_file", { "path" => ".env" })

      expect(result[:success]).to be true
      expect(result[:content]).to include("SECRET_KEY")
    end

    it "does not prompt for blocked files — hard deny" do
      executor = Rubyn::Tools::Executor.new(tmpdir)
      result = executor.execute("read_file", { "path" => "config/master.key" })

      expect(result[:success]).to be false
      expect(result[:error]).to include("protected file")
    end
  end
end
