# CI/CD Integration with Firmo


This guide explains how to set up Firmo in various Continuous Integration (CI) environments to automate your Lua testing workflow.

## Benefits of CI Integration



- Automatically run tests on every commit or pull request
- Catch issues early in the development process
- Ensure code quality across your team
- Generate test reports for tracking quality metrics


## Common CI Systems


### GitHub Actions


GitHub Actions is a CI/CD platform integrated with GitHub that allows you to automate your build, test, and deployment pipeline.

#### Sample Configuration


Create a file at `.github/workflows/test.yml`:


```yaml
name: Lua Tests
on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
jobs:
  test:
    name: Run Firmo Tests
    runs-on: ubuntu-latest
    steps:


      - uses: actions/checkout@v3
      - name: Install Lua

        run: |
          sudo apt-get update
          sudo apt-get install -y lua5.3


      - name: Run tests

        run: |
          # Run all tests in the tests directory
          lua test.lua tests/


      - name: Generate test report (optional)

        run: |
          # If using a reporter/formatter
          lua test.lua tests/ --reporter junit > test-results.xml


      - name: Upload test results

        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results.xml
```



### GitLab CI


GitLab CI/CD is GitLab's built-in tool for software development using continuous integration and delivery.

#### Sample Configuration


Create a file at `.gitlab-ci.yml`:


```yaml
image: ubuntu:latest
stages:


  - test

before_script:


  - apt-get update -qq
  - apt-get install -y lua5.3

run_tests:
  stage: test
  script:


    - lua test.lua tests/

  artifacts:
    when: always
    paths:


      - test-results.xml

    reports:
      junit: test-results.xml
```



### CircleCI


CircleCI is a CI/CD platform that automates the build, test, and deployment process.

#### Sample Configuration


Create a file at `.circleci/config.yml`:


```yaml
version: 2.1
jobs:
  test:
    docker:


      - image: cimg/base:2023.03

    steps:


      - checkout
      - run:

          name: Install Lua
          command: |
            sudo apt-get update
            sudo apt-get install -y lua5.3


      - run:

          name: Run tests
          command: |
            lua test.lua tests/


      - store_test_results:

          path: test-results
workflows:
  version: 2
  build-and-test:
    jobs:


      - test

```



### Jenkins


Jenkins is an open-source automation server that enables developers to build, test, and deploy their software.

#### Sample Jenkinsfile


Create a file at `Jenkinsfile`:


```groovy
pipeline {
    agent any
    stages {
        stage('Setup') {
            steps {
                sh 'apt-get update && apt-get install -y lua5.3'
            }
        }
        stage('Test') {
            steps {
                sh 'lua test.lua tests/'
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }
    }
}
```



## Best Practices for CI Testing


### 1. Organize Tests Properly


Structure your tests in a way that makes them easy to run in CI:


- Place all tests in a dedicated `tests` directory
- Use a consistent naming pattern (e.g., `*_test.lua`)
- Group tests logically by feature or component


### 2. Use Tags for Test Organization



```lua
describe("Database module", function()
  firmo.tags("integration", "database")
  it("connects to the database", function()
    -- Test code
  end)
end)
```


In your CI configuration, you can run specific test groups:


```bash
lua test.lua tests/ --tags unit  # Run only unit tests
lua test.lua tests/ --tags integration  # Run only integration tests
```



### 3. Manage Test Environments


For tests that require specific environment setup:


```yaml

# In GitHub Actions


steps:


  - name: Set up test environment

    run: |
      # Set environment variables
      echo "DB_HOST=localhost" >> $GITHUB_ENV
      echo "API_KEY=test-key" >> $GITHUB_ENV


  - name: Run integration tests

    run: |
      lua test.lua tests/ --tags integration
```



### 4. Configure Test Timeouts


For long-running tests, set appropriate timeouts:


```yaml

# In GitHub Actions


steps:


  - name: Run tests with timeout

    timeout-minutes: 10
    run: |
      lua test.lua tests/
```



### 5. Parallel Test Execution


For large test suites, consider running tests in parallel:


```yaml

# In GitHub Actions


jobs:
  test:
    strategy:
      matrix:
        test-group: [unit, integration, functional]
    steps:


      - name: Run tests

        run: |
          lua test.lua tests/ --tags ${{ matrix.test-group }}
```



## Interpreting Test Results


Firmo provides different output formats to help you interpret test results in CI environments.

### Standard Output


By default, Firmo outputs test results to the console:


```text
Math operations
  PASS adds two numbers correctly
  PASS subtracts two numbers correctly
  FAIL raises an error when dividing by zero
    Expected function to fail but it did not
```



### JUnit XML Format (For CI Systems)


For better CI integration, use the JUnit XML reporter:


```bash
lua test.lua tests/ --reporter junit > test-results.xml
```


This generates an XML file that most CI systems can parse and display as test reports.

### JSON Format (For Custom Processing)


For custom processing of test results:


```bash
lua test.lua tests/ --reporter json > test-results.json
```



## Tips for Effective CI Configuration



1. **Cache dependencies**: Speed up CI runs by caching Lua modules and dependencies.
2. **Fail fast**: Configure your tests to fail as soon as any test fails to get faster feedback.
3. **Notifications**: Set up notifications for test failures to relevant team members.
4. **Branch protection**: Require passing tests before merging pull requests.
5. **Scheduled runs**: Set up scheduled test runs for nightly builds or integration tests.


## Complete Example: GitHub Actions Workflow


This comprehensive example shows a complete GitHub Actions workflow for testing a Lua project with Firmo:


```yaml
name: Lua Testing
on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  schedule:
    # Run nightly at midnight UTC


    - cron: '0 0 * * *'

jobs:
  test:
    name: Lua ${{ matrix.lua-version }} on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        lua-version: ['5.1', '5.2', '5.3', '5.4', 'luajit']
        os: [ubuntu-latest, macos-latest, windows-latest]
    steps:


      - uses: actions/checkout@v3
      - name: Setup Lua

        uses: xpol/setup-lua@v0.3
        with:
          lua-version: ${{ matrix.lua-version }}


      - name: Install dependencies

        run: |
          luarocks install luafilesystem
          luarocks install luasocket


      - name: Run unit tests

        run: lua test.lua tests/ --tags unit --reporter junit > unit-test-results.xml


      - name: Run integration tests

        if: success() || failure() # Run even if unit tests fail
        run: lua test.lua tests/ --tags integration --reporter junit > integration-test-results.xml


      - name: Upload test results

        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results-${{ matrix.lua-version }}-${{ matrix.os }}
          path: |
            *-test-results.xml
```



## Further Resources



- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [CircleCI Documentation](https://circleci.com/docs/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)

For more information on testing strategies, see the [Testing Patterns](testing-patterns.md) guide.
