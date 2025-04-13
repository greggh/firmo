-- cobertura_jenkins_example.lua
-- Example demonstrating Cobertura formatter integration with Jenkins and CI systems
-- Includes XML format details, path mapping, and CI pipeline examples

-- Import the firmo framework
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import required modules
local reporting = require("lib.reporting")
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Simple example module for testing coverage
local network_client = {
  -- Connection functions
  connect = function(host, port, options)
    options = options or {}
    
    -- Input validation
    if not host or type(host) ~= "string" then
      return nil, error_handler.validation_error("Invalid host", {
        expected = "string",
        received = type(host)
      })
    end
    
    if not port or type(port) ~= "number" then
      return nil, error_handler.validation_error("Invalid port", {
        expected = "number",
        received = type(port)
      })
    end
    
    -- Branch example: handle different connection types
    local connection
    if options.secure then
      -- Secure connection (this branch may not be covered in tests)
      connection = {
        host = host,
        port = port,
        type = "secure",
        timeout = options.timeout or 30,
        retry_count = options.retry_count or 3
      }
    else
      -- Standard connection
      connection = {
        host = host,
        port = port,
        type = "standard",
        timeout = options.timeout or 60,
        retry_count = options.retry_count or 1
      }
    end
    
    return connection
  end,
  
  -- Data transfer functions
  send = function(connection, data)
    if not connection then
      return nil, error_handler.validation_error("Invalid connection")
    end
    
    if not data then
      return nil, error_handler.validation_error("Invalid data")
    end
    
    -- Simulate sending data
    local result = {
      bytes_sent = #data,
      timestamp = os.time(),
      success = true
    }
    
    -- This line will not be covered in our tests
    if connection.debug then
      print("Sent", #data, "bytes to", connection.host, ":", connection.port)
    end
    
    return result
  end,
  
  -- Connection management
  disconnect = function(connection)
    if not connection then
      return nil, error_handler.validation_error("Invalid connection")
    end
    
    -- Simple result
    return {
      success = true,
      timestamp = os.time()
    }
  end
}

-- Example tests for generating coverage data
describe("Cobertura Jenkins Example", function()
  -- Resources to clean up
  local temp_dir
  local report_files = {}
  
  -- Create a temp directory before tests
  before(function()
    temp_dir = test_helper.create_temp_test_directory()
  end)
  
  -- Clean up after tests
  after(function()
    for _, file_path in ipairs(report_files) do
      if fs.file_exists(file_path) then
        fs.delete_file(file_path)
      end
    end
  end)
  
  -- Tests to generate coverage data
  describe("Network Client tests", function()
    it("should connect to a host", function()
      local connection = network_client.connect("example.com", 80)
      expect(connection).to.exist()
      expect(connection.host).to.equal("example.com")
      expect(connection.port).to.equal(80)
      expect(connection.type).to.equal("standard")
    end)
    
    it("should handle connection errors", { expect_error = true }, function()
      local connection, err = network_client.connect(nil, 80)
      expect(connection).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Invalid host")
    end)
    
    it("should send data", function()
      local connection = network_client.connect("example.com", 80)
      local result = network_client.send(connection, "test data")
      expect(result).to.exist()
      expect(result.success).to.be_truthy()
      expect(result.bytes_sent).to.equal(9) -- "test data" length
    end)
    
    it("should disconnect", function()
      local connection = network_client.connect("example.com", 80)
      local result = network_client.disconnect(connection)
      expect(result).to.exist()
      expect(result.success).to.be_truthy()
    end)
  end)
  
  -- Cobertura formatter examples
  describe("Cobertura Formatter Features", function()
    it("demonstrates basic Cobertura report generation", function()
      -- Start coverage
      coverage.start()
      
      -- Generate some coverage data
      local connection = network_client.connect("example.com", 8080)
      network_client.send(connection, "Hello, world!")
      network_client.disconnect(connection)
      
      -- Stop coverage
      coverage.stop()
      
      -- Get the coverage data
      local data = coverage.get_data()
      
      -- Configure the Cobertura formatter with default settings
      reporting.configure_formatter("cobertura", {
        pretty = true,  -- Use indentation for readability
        sources_root = "."
      })
      
      -- Generate the report
      local cobertura_report = reporting.format_coverage(data, "cobertura")
      local report_path = fs.join_paths(temp_dir.path, "coverage-report.cobertura")
      local success = reporting.write_file(report_path, cobertura_report)
      
      if success then
        table.insert(report_files, report_path)
        firmo.log.info("Created basic Cobertura report", {
          path = report_path,
          size = #cobertura_report
        })
      end
      
      -- Verify the report contains required XML elements
      expect(cobertura_report).to.match('<?xml version="1.0"')
      expect(cobertura_report).to.match('<coverage')
      expect(cobertura_report).to.match('<sources>')
      expect(cobertura_report).to.match('<packages>')
      expect(cobertura_report).to.match('<classes>')
      expect(cobertura_report).to.match('<lines>')
    end)
    
    it("demonstrates CI path mapping for Jenkins", function()
      -- Start coverage
      coverage.start()
      
      -- Generate coverage data
      local connection = network_client.connect("example.com", 8080, {secure = true})
      network_client.send(connection, "Data for CI test")
      
      -- Stop coverage
      coverage.stop()
      
      -- Get coverage data
      local data = coverage.get_data()
      
      -- Configure for a CI environment with path mapping
      -- This makes paths relative to the workspace directory in Jenkins
      reporting.configure_formatter("cobertura", {
        -- CI specific settings
        sources_root = "${WORKSPACE}",  -- Jenkins workspace variable
        base_directory = "/home/gregg/Projects/lua-library/firmo", -- Current absolute path
        normalize_paths = true,
        path_separator = "/",           -- Use forward slash for all paths
        structure_style = "directory",  -- Use directory structure for packages
        package_depth = 2               -- Use 2 directory levels for packages
      })
      
      -- Generate the CI-friendly report
      local ci_report = reporting.format_coverage(data, "cobertura")
      local ci_report_path = fs.join_paths(temp_dir.path, "jenkins-coverage.cobertura")
      local success = reporting.write_file(ci_report_path, ci_report)
      
      if success then
        table.insert(report_files, ci_report_path)
        firmo.log.info("Created Jenkins-ready Cobertura report", {
          path = ci_report_path,
          size = #ci_report
        })
      end
      
      -- Verify CI path mapping
      expect(ci_report).to.match('<source>${WORKSPACE}</source>')
      -- Paths should not contain the base_directory
      expect(ci_report).to_not.match('/home/gregg/Projects/lua%-library/firmo')
    end)
    
    it("demonstrates branch coverage support", function()
      -- Start coverage
      coverage.start()
      
      -- Generate coverage with branching logic
      local standard = network_client.connect("example.com", 80)
      local secure = network_client.connect("secure.example.com", 443, {secure = true})
      
      network_client.send(standard, "Standard connection data")
      network_client.send(secure, "Secure connection data")
      
      -- Stop coverage
      coverage.stop()
      
      -- Get coverage data
      local data = coverage.get_data()
      
      -- Configure with branch coverage enabled
      reporting.configure_formatter("cobertura", {
        include_branches = true,     -- Enable branch coverage
        pretty = true,
        include_methods = true       -- Include method-level data
      })
      
      -- Generate the report with branch coverage
      local branch_report = reporting.format_coverage(data, "cobertura")
      local branch_report_path = fs.join_paths(temp_dir.path, "branch-coverage.cobertura")
      local success = reporting.write_file(branch_report_path, branch_report)
      
      if success then
        table.insert(report_files, branch_report_path)
        firmo.log.info("Created branch coverage Cobertura report", {
          path = branch_report_path,
          size = #branch_report
        })
      end
      
      -- Verify branch coverage is included
      expect(branch_report).to.match('branch%-rate=')
      expect(branch_report).to.match('branch="true"')
      expect(branch_report).to.match('condition%-coverage')
    end)
    
    it("demonstrates XML validation and threshold checking", function()
      -- Start coverage
      coverage.start()
      
      -- Generate some coverage data
      network_client.connect("example.com", 8080)
      
      -- Stop coverage
      coverage.stop()
      
      -- Get coverage data
      local data = coverage.get_data()
      
      -- Internal validation function (similar to what the formatter uses)
      local function validate_cobertura_xml(xml_string)
        -- Basic validation (simplistic version of what the formatter does)
        local validation_errors = {}
        
        -- Check for required XML elements
        if not xml_string:match('<coverage') then
          table.insert(validation_errors, "Missing root <coverage> element")
        end
        
        if not xml_string:match('line%-rate=') then
          table.insert(validation_errors, "Missing line-rate attribute")
        end
        
        if not xml_string:match('<sources>') then
          table.insert(validation_errors, "Missing <sources> element")
        end
        
        if not xml_string:match('<packages>') then
          table.insert(validation_errors, "Missing <packages> element")
        end
        
        -- Return validation result
        return #validation_errors == 0, validation_errors
      end
      
      -- Generate the report
      local xml_report = reporting.format_coverage(data, "cobertura")
      
      -- Validate the XML
      local is_valid, errors = validate_cobertura_xml(xml_report)
      expect(is_valid).to.be_truthy("Cobertura XML should be valid")
      
      -- Save validated report
      local validated_path = fs.join_paths(temp_dir.path, "validated-coverage.cobertura")
      local success = reporting.write_file(validated_path, xml_report)
      
      if success then
        table.insert(report_files, validated_path)
        firmo.log.info("Created validated Cobertura report", {
          path = validated_path,
          is_valid = is_valid,
          size = #xml_report
        })
      end
    end)
  end)
  
  -- CI/CD Integration Examples
  describe("CI/CD Integration", function()
    it("provides Jenkins pipeline configuration example", function()
      -- This is a documentation example - no actual test
      firmo.log.info("Jenkins Pipeline Example", {
        message = [[
Jenkinsfile example for Cobertura integration:

pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                sh 'luarocks install firmo'
            }
        }
        
        stage('Test') {
            steps {
                sh 'lua test.lua --coverage --format=cobertura tests/'
            }
        }
    }
    
    post {
        always {
            // Process Cobertura report
            cobertura coberturaReportFile: '**/coverage-report.cobertura',
                      onlyStable: false,
                      failNoReports: false,
                      failUnhealthy: false,
                      failUnstable: false,
                      sourceEncoding: 'UTF-8',
                      lineCoverageTargets: '80, 70, 50',     // healthy, unhealthy, failing
                      methodCoverageTargets: '80, 70, 50',
                      classCoverageTargets: '80, 70, 50'
            
            // Archive artifacts
            archiveArtifacts artifacts: '**/coverage-report.*', 
                            allowEmptyArchive: true
        }
    }
}
        ]]
      })
    end)
    
    it("provides SonarQube integration example", function()
      -- Documentation example
      firmo.log.info("SonarQube Integration Example", {
        message = [[
1. Generate Cobertura report:
   lua test.lua --coverage --format=cobertura tests/

2. Configure sonar-project.properties:
   sonar.projectKey=my-lua-project
   sonar.sources=lib
   sonar.tests=tests
   sonar.lua.coverage.reportPaths=coverage-report.cobertura

3. Run SonarQube scanner:
   sonar-scanner -Dsonar.projectKey=my-lua-project -Dsonar.sources=. -Dsonar.lua.coverage.reportPaths=coverage-report.cobertura
        ]]
      })
    end)
    
    it("provides GitHub Actions example", function()
      -- Documentation example
      firmo.log.info("GitHub Actions Example", {
        message = [[
GitHub Actions workflow example (.github/workflows/test.yml):

name: Test and Coverage
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Lua
        uses: leafo/gh-actions-lua@v8
        
      - name: Run tests with coverage
        run: lua test.lua --coverage --format=cobertura tests/
      
      - name: Upload coverage report to Codecov
        uses: codecov/codecov-action@v2
        with:
          files: ./coverage-report.cobertura
          fail_ci_if_error: true
        ]]
      })
    end)
    
    

