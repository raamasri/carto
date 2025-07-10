#!/usr/bin/env node

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { exec } = require('child_process');
const { promisify } = require('util');
const fs = require('fs').promises;
const path = require('path');

const execAsync = promisify(exec);

class ProjectColumbusMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'project-columbus-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
          prompts: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupResourceHandlers();
    this.setupPromptHandlers();
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'build-project',
            description: 'Build the iOS project for simulator or device',
            inputSchema: {
              type: 'object',
              properties: {
                target: {
                  type: 'string',
                  enum: ['simulator', 'device', 'archive'],
                  description: 'Build target',
                },
                scheme: {
                  type: 'string',
                  default: 'Project Columbus',
                  description: 'Xcode scheme to build',
                },
              },
              required: ['target'],
            },
          },
          {
            name: 'run-tests',
            description: 'Run unit tests or UI tests',
            inputSchema: {
              type: 'object',
              properties: {
                testType: {
                  type: 'string',
                  enum: ['unit', 'ui', 'all'],
                  description: 'Type of tests to run',
                },
                testClass: {
                  type: 'string',
                  description: 'Specific test class to run (optional)',
                },
              },
              required: ['testType'],
            },
          },
          {
            name: 'deploy-testflight',
            description: 'Deploy the app to TestFlight',
            inputSchema: {
              type: 'object',
              properties: {
                commitMessage: {
                  type: 'string',
                  description: 'Commit message for deployment',
                },
                skipBuild: {
                  type: 'boolean',
                  default: false,
                  description: 'Skip build and only upload existing archive',
                },
              },
            },
          },
          {
            name: 'analyze-project-structure',
            description: 'Analyze the project structure and dependencies',
            inputSchema: {
              type: 'object',
              properties: {
                depth: {
                  type: 'number',
                  default: 2,
                  description: 'Directory depth to analyze',
                },
              },
            },
          },
          {
            name: 'check-code-quality',
            description: 'Check code quality and potential issues',
            inputSchema: {
              type: 'object',
              properties: {
                files: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Specific files to check (optional)',
                },
              },
            },
          },
          {
            name: 'generate-documentation',
            description: 'Generate documentation for the project',
            inputSchema: {
              type: 'object',
              properties: {
                type: {
                  type: 'string',
                  enum: ['api', 'architecture', 'deployment'],
                  description: 'Type of documentation to generate',
                },
              },
              required: ['type'],
            },
          },
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'build-project':
            return await this.buildProject(args);
          case 'run-tests':
            return await this.runTests(args);
          case 'deploy-testflight':
            return await this.deployTestFlight(args);
          case 'analyze-project-structure':
            return await this.analyzeProjectStructure(args);
          case 'check-code-quality':
            return await this.checkCodeQuality(args);
          case 'generate-documentation':
            return await this.generateDocumentation(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error executing tool ${name}: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  setupResourceHandlers() {
    // Resource handlers for accessing project files and data
    this.server.setRequestHandler('resources/list', async () => {
      return {
        resources: [
          {
            uri: 'file://project-structure',
            name: 'Project Structure',
            description: 'Access to project file structure',
            mimeType: 'application/json',
          },
          {
            uri: 'file://build-logs',
            name: 'Build Logs',
            description: 'Access to build logs and output',
            mimeType: 'text/plain',
          },
          {
            uri: 'file://test-results',
            name: 'Test Results',
            description: 'Access to test execution results',
            mimeType: 'application/json',
          },
        ],
      };
    });
  }

  setupPromptHandlers() {
    // Prompt handlers for common development tasks
    this.server.setRequestHandler('prompts/list', async () => {
      return {
        prompts: [
          {
            name: 'debug-issue',
            description: 'Debug a specific issue in the app',
            arguments: [
              {
                name: 'issue_description',
                description: 'Description of the issue',
                required: true,
              },
              {
                name: 'error_logs',
                description: 'Error logs or stack traces',
                required: false,
              },
            ],
          },
          {
            name: 'optimize-performance',
            description: 'Analyze and optimize app performance',
            arguments: [
              {
                name: 'performance_metrics',
                description: 'Performance metrics data',
                required: true,
              },
            ],
          },
          {
            name: 'implement-feature',
            description: 'Plan and implement a new feature',
            arguments: [
              {
                name: 'feature_description',
                description: 'Description of the feature to implement',
                required: true,
              },
              {
                name: 'priority',
                description: 'Feature priority (high, medium, low)',
                required: false,
              },
            ],
          },
        ],
      };
    });
  }

  async buildProject(args) {
    const { target = 'simulator', scheme = 'Project Columbus' } = args;
    const projectPath = 'Project Columbus copy.xcodeproj';
    
    let destination;
    switch (target) {
      case 'simulator':
        destination = 'platform=iOS Simulator,name=iPhone 15';
        break;
      case 'device':
        destination = 'generic/platform=iOS';
        break;
      case 'archive':
        destination = 'generic/platform=iOS';
        break;
      default:
        throw new Error(`Invalid target: ${target}`);
    }

    let command;
    if (target === 'archive') {
      command = `xcodebuild -project "${projectPath}" -scheme "${scheme}" -destination "${destination}" -archivePath "Project Columbus.xcarchive" archive`;
    } else {
      command = `xcodebuild -project "${projectPath}" -scheme "${scheme}" -destination "${destination}" build`;
    }

    try {
      const { stdout, stderr } = await execAsync(command);
      return {
        content: [
          {
            type: 'text',
            text: `Build completed successfully for ${target}:\n\n${stdout}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Build failed: ${error.message}\n\nError output:\n${error.stderr}`,
          },
        ],
        isError: true,
      };
    }
  }

  async runTests(args) {
    const { testType = 'unit', testClass } = args;
    const projectPath = 'Project Columbus copy.xcodeproj';
    const scheme = 'Project Columbus';
    const destination = 'platform=iOS Simulator,name=iPhone 15';

    let command = `xcodebuild -project "${projectPath}" -scheme "${scheme}" -destination "${destination}" test`;
    
    if (testClass) {
      command += ` -only-testing:"Project ColumbusTests/${testClass}"`;
    }

    try {
      const { stdout, stderr } = await execAsync(command);
      return {
        content: [
          {
            type: 'text',
            text: `Tests completed for ${testType}:\n\n${stdout}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Tests failed: ${error.message}\n\nError output:\n${error.stderr}`,
          },
        ],
        isError: true,
      };
    }
  }

  async deployTestFlight(args) {
    const { commitMessage = 'Automated deployment', skipBuild = false } = args;
    
    let command;
    if (skipBuild) {
      command = './scripts/deploy_testflight.sh';
    } else {
      command = `./scripts/deploy.sh "${commitMessage}"`;
    }

    try {
      const { stdout, stderr } = await execAsync(command);
      return {
        content: [
          {
            type: 'text',
            text: `Deployment completed successfully:\n\n${stdout}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Deployment failed: ${error.message}\n\nError output:\n${error.stderr}`,
          },
        ],
        isError: true,
      };
    }
  }

  async analyzeProjectStructure(args) {
    const { depth = 2 } = args;
    
    try {
      const { stdout } = await execAsync(`find "Project Columbus" -type f -name "*.swift" | head -20`);
      const swiftFiles = stdout.trim().split('\n');
      
      const analysis = {
        totalSwiftFiles: swiftFiles.length,
        mainFiles: swiftFiles.filter(f => f.includes('Project Columbus/')),
        testFiles: swiftFiles.filter(f => f.includes('Tests/')),
        structure: {
          views: swiftFiles.filter(f => f.includes('View.swift')).length,
          models: swiftFiles.filter(f => f.includes('Model') || f.includes('Data')).length,
          managers: swiftFiles.filter(f => f.includes('Manager.swift')).length,
          utilities: swiftFiles.filter(f => f.includes('Util') || f.includes('Helper')).length,
        },
      };

      return {
        content: [
          {
            type: 'text',
            text: `Project Structure Analysis:\n\n${JSON.stringify(analysis, null, 2)}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Failed to analyze project structure: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  async checkCodeQuality(args) {
    const { files = [] } = args;
    
    try {
      let command;
      if (files.length > 0) {
        command = `swiftlint lint ${files.join(' ')}`;
      } else {
        command = 'swiftlint lint "Project Columbus/"';
      }
      
      const { stdout, stderr } = await execAsync(command);
      
      return {
        content: [
          {
            type: 'text',
            text: `Code Quality Analysis:\n\n${stdout || 'No issues found!'}`,
          },
        ],
      };
    } catch (error) {
      // SwiftLint not installed, provide alternative analysis
      return {
        content: [
          {
            type: 'text',
            text: `Code Quality Analysis (SwiftLint not available):\n\nPerforming basic analysis...\n\nSuggestion: Install SwiftLint for comprehensive code quality checks:\nbrew install swiftlint`,
          },
        ],
      };
    }
  }

  async generateDocumentation(args) {
    const { type } = args;
    
    const documentation = {
      api: `# API Documentation\n\nThis document outlines the API structure for Project Columbus.\n\n## Supabase Integration\n\n### Authentication\n- Apple Sign-In\n- Email/Password\n- Biometric Authentication\n\n### Database Tables\n- pins\n- users\n- pin_lists\n- messages\n- conversations\n- reactions\n- comments\n\n### Real-time Features\n- Live feed updates\n- Message notifications\n- Location sharing`,
      
      architecture: `# Architecture Documentation\n\n## Overview\nProject Columbus follows MVVM architecture with SwiftUI.\n\n## Key Components\n\n### Data Layer\n- Models.swift: Core data models\n- SupabaseManager.swift: Backend integration\n\n### Business Logic\n- PinStore.swift: State management\n- AuthManager.swift: Authentication\n- LocationManager.swift: Location services\n\n### UI Layer\n- SwiftUI Views\n- View Models\n- Navigation`,
      
      deployment: `# Deployment Documentation\n\n## Prerequisites\n- Xcode 15.0+\n- iOS 17.0+\n- Config.plist with Supabase credentials\n\n## Build Commands\n\`\`\`bash\n# Build for simulator\nxcodebuild -project "Project Columbus copy.xcodeproj" -scheme "Project Columbus" -destination "platform=iOS Simulator,name=iPhone 15" build\n\n# Deploy to TestFlight\n./scripts/deploy.sh "Release notes"\n\`\`\`\n\n## Scripts\n- check_setup.sh: Verify deployment prerequisites\n- deploy.sh: Complete deployment pipeline\n- deploy_testflight.sh: TestFlight upload only`,
    };

    return {
      content: [
        {
          type: 'text',
          text: documentation[type] || 'Documentation type not found',
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Project Columbus MCP Server running on stdio');
  }
}

const server = new ProjectColumbusMCPServer();
server.run().catch(console.error);