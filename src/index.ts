#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
  ErrorCode,
  McpError,
} from "@modelcontextprotocol/sdk/types.js";
import { chromium, Browser, Page } from 'playwright';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import axios from 'axios';
import { exec } from 'child_process';
import { promisify } from 'util';

// Configuration interface
interface JulesConfig {
  headless: boolean;
  timeout: number;
  debug: boolean;
  dataPath: string;
  baseUrl: string;
  userDataDir?: string;
  useExistingSession: boolean;
  cookiePath?: string;
  sessionMode: 'fresh' | 'chrome-profile' | 'cookies' | 'persistent' | 'browserbase';
  // Browserbase configuration
  browserbaseApiKey?: string;
  browserbaseProjectId?: string;
  browserbaseSessionId?: string;
  // Cookie strings for manual configuration
  googleAuthCookies?: string;
  // Jules API Key (PAT)
  julesApiKey?: string;
  // Path to Jules CLI (e.g., jules.cmd)
  julesCliPath?: string;
  // Workspace Directory for Jules CLI execution
  workspaceDir?: string;
}

// Browserbase session interface
interface BrowserbaseSession {
  id: string;
  status: string;
  connectUrl: string;
}

// Task data interfaces
interface JulesTask {
  id: string;
  title: string;
  description: string;
  repository: string;
  branch: string;
  status: 'pending' | 'in_progress' | 'completed' | 'paused';
  type: 'standard' | 'delegated';
  marker?: string;
  createdAt: string;
  updatedAt: string;
  url: string;
  chatHistory: ChatMessage[];
  sourceFiles: SourceFile[];
}

interface ChatMessage {
  timestamp: string;
  content: string;
  type: 'user' | 'jules' | 'system';
}

interface SourceFile {
  filename: string;
  url: string;
  status: 'modified' | 'created' | 'deleted' | 'unchanged';
}

export class GoogleJulesMCP {
  public server: Server;
  private browser: Browser | null = null;
  private page: Page | null = null;
  private config: JulesConfig;
  private dataPath: string;

  constructor() {
    this.config = {
      headless: process.env.HEADLESS !== 'false',
      timeout: parseInt(process.env.TIMEOUT || '30000'),
      debug: process.env.DEBUG === 'true',
      dataPath: process.env.JULES_DATA_PATH || path.join(os.homedir(), '.jules-mcp', 'data.json'),
      baseUrl: 'https://jules.google.com',
      userDataDir: process.env.CHROME_USER_DATA_DIR,
      useExistingSession: process.env.USE_EXISTING_SESSION === 'true',
      cookiePath: process.env.COOKIES_PATH,
      sessionMode: (process.env.SESSION_MODE as any) || 'fresh',
      // Browserbase configuration
      browserbaseApiKey: process.env.BROWSERBASE_API_KEY,
      browserbaseProjectId: process.env.BROWSERBASE_PROJECT_ID,
      browserbaseSessionId: process.env.BROWSERBASE_SESSION_ID,
      // Google Auth Cookies as string
      googleAuthCookies: process.env.GOOGLE_AUTH_COOKIES,
      // Jules API Key
      julesApiKey: process.env.JULES_API_KEY,
      // Jules CLI Path
      julesCliPath: process.env.JULES_CLI_PATH || "jules"
    };

    this.dataPath = this.config.dataPath;

    this.server = new Server(
      {
        name: 'google-jules-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupResourceHandlers();
  }

  private setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          // === CORE TASK MANAGEMENT ===
          {
            name: 'jules_create_task',
            description: 'Create a new task in Google Jules with repository and description',
            inputSchema: {
              type: 'object',
              properties: {
                description: {
                  type: 'string',
                  description: 'Task description - what you want Jules to do',
                },
                repository: {
                  type: 'string',
                  description: 'GitHub repository in format owner/repo-name',
                },
                branch: {
                  type: 'string',
                  description: 'Git branch to work on (optional, defaults to main)',
                },
              },
              required: ['description', 'repository'],
            },
          },
          {
            name: 'jules_get_task',
            description: 'Get details of a specific Jules task by ID or URL',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or full Jules task URL',
                },
              },
              required: ['taskId'],
            },
          },
          {
            name: 'jules_list_tasks',
            description: 'List all Jules tasks with their status',
            inputSchema: {
              type: 'object',
              properties: {
                status: {
                  type: 'string',
                  enum: ['all', 'active', 'pending', 'completed', 'paused'],
                  description: 'Filter tasks by status',
                },
                repository: {
                  type: 'string',
                  description: 'Filter tasks by repository (owner/repo). Auto-detects if omitted in local git context.',
                },
                limit: {
                  type: 'number',
                  description: 'Maximum number of tasks to return (default 10)',
                },
              },
            },
          },
          {
            name: 'jules_send_message',
            description: 'Send a message/instruction to Jules in an active task',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or URL',
                },
                message: {
                  type: 'string',
                  description: 'Message to send to Jules',
                },
              },
              required: ['taskId', 'message'],
            },
          },
          {
            name: 'jules_approve_plan',
            description: 'Approve Jules execution plan for a task',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or URL',
                },
              },
              required: ['taskId'],
            },
          },
          {
            name: 'jules_resume_task',
            description: 'Resume a paused Jules task',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or URL',
                },
              },
              required: ['taskId'],
            },
          },
          {
            name: 'jules_check_feedback',
            description: 'Scans all active tasks for sessions in AWAITING_USER_FEEDBACK state and retrieves questions from Jules.',
            inputSchema: {
              type: 'object',
              properties: {
                repository: {
                  type: 'string',
                  description: 'Optional filter by repository (owner/repo).',
                },
              }
            },
          },
          {
            name: 'jules_delegate_task',
            description: 'The most efficient way to initiate delegatings. Triggers a Jules task on a remote branch after optionally pushing local changes. Jules will specifically look for instructions marked in the code.',
            inputSchema: {
              type: 'object',
              properties: {
                repository: {
                  type: 'string',
                  description: 'GitHub repository (owner/repo). Auto-detected if omitted.',
                },
                branch: {
                  type: 'string',
                  description: 'Git branch. Auto-detected if omitted.',
                },
                marker: {
                  type: 'string',
                  description: 'Marker string to look for in code (default: @jules)',
                },
                pushFirst: {
                  type: 'boolean',
                  description: 'Whether to push the current branch to origin before initiating task (default: true)',
                },
              }
            },
          },
          {
            name: 'jules_audit_report',
            description: 'Generates a formal audit report for a Jules session, consolidating intent, activity logs, and code outcomes for compliance and verification.',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or URL to audit.',
                },
              },
              required: ['taskId'],
            },
          },
          {
            name: 'jules_code_review',
            description: 'Extracts the most recent code review or reasoning analysis from a Jules session. Provides insights into Jules decisions and verification ratings.',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or URL to inspect.',
                },
              },
              required: ['taskId'],
            },
          },
          // === ADVANCED TASK OPERATIONS ===
          {
            name: 'jules_analyze_code',
            description: 'Analyze code changes and diff in a Jules task',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Task ID or URL',
                },
                includeSourceCode: {
                  type: 'boolean',
                  description: 'Whether to include full source code content',
                },
                returnPatch: {
                  type: 'boolean',
                  description: 'Whether to return the raw git patch (useful for salvaging failed tasks)',
                },
              },
              required: ['taskId'],
            },
          },
          {
            name: 'jules_bulk_create_tasks',
            description: 'Create multiple tasks from a list of descriptions and repositories',
            inputSchema: {
              type: 'object',
              properties: {
                tasks: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      description: { type: 'string' },
                      repository: { type: 'string' },
                      branch: { type: 'string' },
                    },
                    required: ['description', 'repository'],
                  },
                  description: 'Array of task objects to create',
                },
              },
              required: ['tasks'],
            },
          },
          // === SESSION & AUTHENTICATION MANAGEMENT ===
          {
            name: 'jules_session_info',
            description: 'Get current session configuration and authentication status',
            inputSchema: {
              type: 'object',
              properties: {},
            },
          },
          {
            name: 'jules_setup_wizard',
            description: 'Interactive session setup wizard for automated Google authentication configuration',
            inputSchema: {
              type: 'object',
              properties: {
                environment: {
                  type: 'string',
                  enum: ['local', 'cloud', 'smithery', 'auto-detect'],
                  description: 'Deployment environment (auto-detect will analyze current setup)',
                },
                preferences: {
                  type: 'object',
                  properties: {
                    priority: {
                      type: 'string',
                      enum: ['ease-of-use', 'reliability', 'portability', 'performance'],
                      description: 'User priority for session management'
                    },
                    hasChrome: {
                      type: 'boolean',
                      description: 'Whether user has local Chrome browser access'
                    },
                    cloudDeployment: {
                      type: 'boolean',
                      description: 'Whether deploying to cloud platforms'
                    }
                  }
                }
              },
            },
          },
          {
            name: 'jules_get_cookies',
            description: 'Extract current browser cookies for session persistence and backup',
            inputSchema: {
              type: 'object',
              properties: {
                format: {
                  type: 'string',
                  enum: ['json', 'string'],
                  description: 'Output format for cookies (default: json)',
                },
              },
            },
          },
          {
            name: 'jules_set_cookies',
            description: 'Set browser cookies from string or JSON for authentication',
            inputSchema: {
              type: 'object',
              properties: {
                cookies: {
                  type: 'string',
                  description: 'Cookies as JSON string or cookie string format',
                },
                format: {
                  type: 'string',
                  enum: ['json', 'string'],
                  description: 'Format of input cookies (default: json)',
                },
              },
              required: ['cookies'],
            },
          },
          {
            name: "jules_cli",
            description: "Execute a command using the Jules CLI for token efficiency",
            inputSchema: {
              type: "object",
              properties: {
                args: {
                  type: "array",
                  items: { type: "string" },
                  description: "Arguments to pass to the jules command",
                },
              },
              required: ["args"],
            },
          },
          // === DEBUGGING & UTILITIES ===
          {
            name: 'jules_screenshot',
            description: 'Take a screenshot of current Jules page for debugging and verification',
            inputSchema: {
              type: 'object',
              properties: {
                taskId: {
                  type: 'string',
                  description: 'Optional task ID to navigate to first',
                },
                filename: {
                  type: 'string',
                  description: 'Optional filename for screenshot',
                },
              },
            },
          },
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'jules_create_task':
            return await this.createTask(args);
          case 'jules_get_task':
            return await this.getTask(args);
          case 'jules_send_message':
            return await this.sendMessage(args);
          case 'jules_approve_plan':
            return await this.approvePlan(args);
          case 'jules_resume_task':
            return await this.resumeTask(args);
          case 'jules_check_feedback':
            return await this.checkFeedback(args);
          case 'jules_audit_report':
            return await this.generateAuditReport(args);
          case 'jules_code_review':
            return await this.getCodeReview(args);
          case 'jules_delegate_task':
            return await this.initiateDelegation(args);
          case 'jules_list_tasks':
            return await this.listTasks(args);
          case 'jules_analyze_code':
            return await this.analyzeCode(args);
          case 'jules_bulk_create_tasks':
            return await this.bulkCreateTasks(args);
          case "jules_cli":
            const cliArgs = (args as any).args as string[];
            const output = await this.runJulesCli(cliArgs);
            return {
              content: [{ type: "text", text: output }]
            };
          case 'jules_screenshot':
            return await this.takeScreenshot(args);
          case 'jules_get_cookies':
            return await this.getCookies(args);
          case 'jules_set_cookies':
            return await this.setCookies(args);
          case 'jules_session_info':
            return await this.getSessionInfo(args);
          case 'jules_setup_wizard':
            return await this.setupWizard(args);
          default:
            throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        throw new McpError(ErrorCode.InternalError, `Error in ${name}: ${errorMessage}`);
      }
    });
  }

  private setupResourceHandlers() {
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => {
      return {
        resources: [
          {
            uri: 'jules://schemas/task',
            name: 'Task Schema',
            description: 'Complete task model with all available attributes',
            mimeType: 'application/json'
          },
          {
            uri: 'jules://current/active-tasks',
            name: 'Active Tasks',
            description: 'Live list of active tasks in Jules',
            mimeType: 'application/json'
          },
          {
            uri: 'jules://templates/common-tasks',
            name: 'Common Task Templates',
            description: 'Template examples for common development tasks',
            mimeType: 'application/json'
          },
          {
            uri: 'jules://prompts/session-setup',
            name: 'Session Setup Automation',
            description: 'Step-by-step prompts for automated Google authentication setup',
            mimeType: 'text/plain'
          },
          {
            uri: 'jules://prompts/cookie-extraction',
            name: 'Cookie Extraction Guide',
            description: 'Automated prompts for extracting Google authentication cookies',
            mimeType: 'text/plain'
          },
          {
            uri: 'jules://prompts/browserbase-setup',
            name: 'Browserbase Configuration',
            description: 'Automated Browserbase setup for remote browser sessions',
            mimeType: 'text/plain'
          },
          {
            uri: 'jules://guides/session-modes',
            name: 'Session Mode Selection Guide',
            description: 'Intelligent guide for choosing the optimal session management mode',
            mimeType: 'text/plain'
          },
          {
            uri: 'jules://troubleshooting/authentication',
            name: 'Authentication Troubleshooting',
            description: 'Automated diagnostics and fixes for authentication issues',
            mimeType: 'text/plain'
          },
        ]
      };
    });

    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const uri = request.params.uri;

      switch (uri) {
        case 'jules://schemas/task':
          return {
            contents: [{
              uri,
              mimeType: 'application/json',
              text: JSON.stringify({
                id: 'string',
                title: 'string',
                description: 'string',
                repository: 'string (owner/repo-name)',
                branch: 'string',
                status: 'pending | in_progress | completed | paused',
                createdAt: 'ISO timestamp',
                updatedAt: 'ISO timestamp',
                url: 'Jules task URL',
                chatHistory: 'array of chat messages',
                sourceFiles: 'array of modified files'
              }, null, 2)
            }]
          };
        case 'jules://current/active-tasks':
          const activeTasks = await this.getActiveTasks();
          return {
            contents: [{
              uri,
              mimeType: 'application/json',
              text: JSON.stringify(activeTasks, null, 2)
            }]
          };
        case 'jules://templates/common-tasks':
          return {
            contents: [{
              uri,
              mimeType: 'application/json',
              text: JSON.stringify({
                'bug-fix': 'Fix the [specific issue] in [filename]. The problem is [description].',
                'feature-add': 'Add [feature name] functionality to [location]. Requirements: [list requirements].',
                'refactor': 'Refactor [component/function] to improve [performance/readability/maintainability].',
                'test-add': 'Add comprehensive tests for [component/function] covering [test cases].',
                'documentation': 'Update documentation for [component] to include [new features/changes].',
                'dependency-update': 'Update [dependency name] to version [version] and fix any breaking changes.',
                'security-fix': 'Fix security vulnerability in [location]: [description of vulnerability].',
                'performance': 'Optimize [component/function] performance by [specific optimization approach].'
              }, null, 2)
            }]
          };
        case 'jules://prompts/session-setup':
          return {
            contents: [{
              uri,
              mimeType: 'text/plain',
              text: `# Jules MCP Session Setup Automation

## Agent Instructions for Automated Google Authentication Setup

You are helping a user configure Google Jules MCP with persistent authentication. Follow these steps systematically:

### STEP 1: Determine User's Environment
Ask the user about their deployment environment:
- "Are you deploying locally or on a cloud platform like Smithery?"
- "Do you have access to your local Chrome browser?"
- "Are you planning to use this MCP from multiple locations?"

### STEP 2: Recommend Optimal Session Mode
Based on their answers, recommend:

**For Cloud/Remote Deployment (Smithery):**
- Recommend: "SESSION_MODE=browserbase"
- Explain: "This uses remote browsers and works perfectly for cloud deployments"
- Next: Proceed to Browserbase setup

**For Local Development:**
- Recommend: "SESSION_MODE=chrome-profile"
- Explain: "This uses your existing Chrome login"
- Next: Help find Chrome profile path

**For Manual Cookie Management:**
- Recommend: "SESSION_MODE=cookies"
- Explain: "This saves authentication cookies as text"
- Next: Proceed to cookie extraction

### STEP 3: Execute Setup Based on Mode

If BROWSERBASE:
1. Read jules://prompts/browserbase-setup for detailed instructions
2. Help configure API keys and project settings
3. Test connection

If CHROME-PROFILE:
1. Read jules://guides/session-modes for profile detection
2. Help locate Chrome user data directory
3. Configure environment variables

If COOKIES:
1. Read jules://prompts/cookie-extraction for step-by-step extraction
2. Help format cookies for environment variables
3. Test authentication

### STEP 4: Validate Setup
Always end by:
1. Using jules_session_info to check configuration
2. Testing with a simple jules_create_task call
3. Confirming Google authentication works

### AUTOMATION COMMANDS TO USE:
- \`jules_session_info\` - Check current configuration
- \`jules_get_cookies\` - Extract authentication cookies
- \`jules_set_cookies\` - Test cookie authentication
- \`jules_screenshot\` - Debug authentication issues

Remember: Be proactive and guide the user through each step. Don't just provide information - actively help configure and test the setup.`
            }]
          };
        case 'jules://prompts/cookie-extraction':
          return {
            contents: [{
              uri,
              mimeType: 'text/plain',
              text: `# Automated Google Authentication Cookie Extraction

## Agent Instructions for Cookie-Based Authentication

You are helping extract Google authentication cookies for Jules MCP. Follow this exact process:

### STEP 1: Guide User to Login
Instruct the user:
1. "Open Chrome and navigate to https://jules.google.com"
2. "Make sure you are fully logged in and can access Jules"
3. "Complete any 2FA or verification if prompted"

### STEP 2: Extract Cookies via Developer Tools
Guide them step-by-step:

1. **Open Developer Tools:**
   - "Press F12 (or Cmd+Option+I on Mac)"
   - "Click on the 'Application' tab (or 'Storage' in Firefox)"

2. **Navigate to Cookies:**
   - "In the left sidebar, find 'Cookies'"
   - "Click to expand the cookies section"
   - "Click on 'https://jules.google.com'"

3. **Identify Key Cookies:**
   Look for these important authentication cookies:
   - \`session_id\`, \`sessionid\`, or similar
   - \`auth_token\`, \`authuser\`, or similar
   - \`SID\`, \`HSID\`, \`SSID\` (Google-specific)
   - \`SAPISID\`, \`APISID\` (API authentication)
   - Any cookie with 'auth' or 'session' in the name

### STEP 3: Format Cookies for Environment Variable
Help format as: \
ame=value; domain=.google.com; name2=value2; domain=.google.com\`

Example:
\`\`\`
GOOGLE_AUTH_COOKIES="sessionid=abc123def456; domain=.google.com; auth_token=xyz789; domain=.google.com; SID=A1B2C3; domain=.google.com"
\`\`\`

### STEP 4: Alternative - Use MCP Tools
If the user has the MCP running with basic access:
1. Use \`jules_get_cookies\` to extract current session
2. Save the output for environment configuration
3. Use \`jules_set_cookies\` to test the extracted cookies

### STEP 5: Test Configuration
1. Set the environment variable
2. Restart the MCP with SESSION_MODE=cookies
3. Use \`jules_session_info\` to verify configuration
4. Test with a simple task creation

### TROUBLESHOOTING:
- If authentication fails, re-extract cookies (they expire)
- Make sure to include the domain information
- Check that Jules is accessible in a normal browser first

### AUTOMATION APPROACH:
If possible, automate this by:
1. Taking a screenshot of the current Jules page
2. Using jules_get_cookies if browser access is available
3. Providing formatted output ready for environment variables`
            }]
          };
        case 'jules://prompts/browserbase-setup':
          return {
            contents: [{
              uri,
              mimeType: 'text/plain',
              text: `# Automated Browserbase Setup for Remote Jules MCP

## Agent Instructions for Browserbase Configuration

You are setting up Browserbase for cloud-based Google Jules automation. This is perfect for Smithery deployments.

### STEP 1: Explain Browserbase Benefits
Tell the user:
- "Browserbase provides remote browsers in the cloud"
- "Perfect for Smithery deployments - no local browser needed"
- "Maintains persistent Google sessions across deployments"
- "Works from anywhere with internet connection"

### STEP 2: Use Provided Credentials (If Available)
We have test credentials available:
\`\`\`
BROWSERBASE_API_KEY=bb_live_g3i-b4WPFh__E3cErKE5rO-jWds
BROWSERBASE_PROJECT_ID=d718e85f-be7b-497d-9123-b1bbf798f1bb
\`\`\`

### STEP 3: Configure Environment Variables
Help set up these variables:

**For Smithery Deployment:**
1. In Smithery settings, add:
   - \`SESSION_MODE=browserbase\`
   - \`BROWSERBASE_API_KEY=bb_live_g3i-b4WPFh__E3cErKE5rO-jWds\`
   - \`BROWSERBASE_PROJECT_ID=d718e85f-be7b-497d-9123-b1bbf798f1bb\`

**For Local Testing:**
1. Set environment variables:
   \`\`\`bash
   export SESSION_MODE=browserbase
   export BROWSERBASE_API_KEY=bb_live_g3i-b4WPFh__E3cErKE5rO-jWds
   export BROWSERBASE_PROJECT_ID=d718e85f-be7b-497d-9123-b1bbf798f1bb
   \`\`\`

### STEP 4: Test Browserbase Connection
1. Use \`jules_session_info\` to verify Browserbase configuration
2. The output should show:
   - \`sessionMode: "browserbase"\`
   - \`hasBrowserbaseConfig: true\`
   - \`browserbaseSessionId: null\` (will be created automatically)

### STEP 5: First-Time Authentication Setup
When you first use Browserbase:
1. The MCP will create a new browser session in the cloud
2. You'll need to authenticate with Google in that remote browser
3. To do this systematically:
   - Use \`jules_screenshot\` to see the current browser state
   - If authentication is needed, the screenshot will show login prompts
   - Guide the user through cloud-based authentication

### STEP 6: Session Persistence
Once authenticated:
- Browserbase will maintain the session
- Future MCP calls will use the authenticated session
- No need to re-authenticate unless session expires

### AUTOMATION COMMANDS:
- \`jules_session_info\` - Check Browserbase configuration
- \`jules_screenshot\` - See remote browser state
- \`jules_create_task\` - Test end-to-end functionality

### TROUBLESHOOTING:
- If connection fails, verify API key and project ID
- If authentication issues, take screenshots to debug
- Sessions may need periodic refresh

### SMITHERY DEPLOYMENT:
For Smithery users:
1. Fork the google-jules-mcp repository
2. Deploy to Smithery with Browserbase environment variables
3. The MCP will automatically handle remote browser management
4. Access from any Claude Code instance globally

This approach completely eliminates local browser dependency!`
            }]
          };
        case 'jules://guides/session-modes':
          return {
            contents: [{
              uri,
              mimeType: 'text/plain',
              text: `# Intelligent Session Mode Selection Guide

## Agent Decision Tree for Optimal Session Configuration

Use this guide to automatically determine the best session mode for each user:

### DECISION MATRIX:

**User Says: "I want to deploy on Smithery/cloud"**
→ **RECOMMEND: browserbase**
→ REASON: Remote browsers, no local dependencies
→ NEXT: Read jules://prompts/browserbase-setup

**User Says: "I'm developing locally" + "I use Chrome for Google services"**
→ **RECOMMEND: chrome-profile**
→ REASON: Leverage existing Google authentication
→ NEXT: Detect Chrome profile path

**User Says: "I need this to work on multiple machines"**
→ **RECOMMEND: cookies**
→ REASON: Portable authentication via environment variables
→ NEXT: Read jules://prompts/cookie-extraction

**User Says: "I want maximum reliability and control"**
→ **RECOMMEND: persistent**
→ REASON: Local browser data persistence, full control
→ NEXT: Configure persistent directory

**User Says: "I just want to test quickly"**
→ **RECOMMEND: fresh**
→ REASON: No setup required, clean testing environment
→ NEXT: Explain manual authentication per session

### CHROME PROFILE DETECTION:

For \`chrome-profile\` mode, help find the user data directory:

**macOS:**
\`/Users/[username]/Library/Application Support/Google/Chrome/Default\`

**Windows:**
\`C:\\Users\\[username]\\AppData\\Local\\Google\\Chrome\\User Data\\Default\`

**Linux:**
\`/home/[username]/.config/google-chrome/Default\`

### AUTOMATION SCRIPTS:

**Detect Chrome Profile (macOS/Linux):**
\`\`\`bash
find ~/Library/Application\\ Support/Google/Chrome -name "Default" -type d 2>/dev/null
find ~/.config/google-chrome -name "Default" -type d 2>/dev/null
\`\`\`

**Test Profile Access:**
Check if profile directory exists and contains "Preferences" file

### ENVIRONMENT VARIABLE TEMPLATES:

**Browserbase:**
\`\`\`
SESSION_MODE=browserbase
BROWSERBASE_API_KEY=bb_live_g3i-b4WPFh__E3cErKE5rO-jWds
BROWSERBASE_PROJECT_ID=d718e85f-be7b-497d-9123-b1bbf798f1bb
\`\`\`

**Chrome Profile:**
\`\`\`
SESSION_MODE=chrome-profile
CHROME_USER_DATA_DIR=/path/to/chrome/profile
\`\`\`

**Cookies:**
\`\`\`
SESSION_MODE=cookies
GOOGLE_AUTH_COOKIES="session_id=...; domain=.google.com"
COOKIES_PATH=~/.jules-mcp/cookies.json
\`\`\`

**Persistent:**
\`\`\`
SESSION_MODE=persistent
CHROME_USER_DATA_DIR=~/.jules-mcp/browser-data
\`\`\`

### VALIDATION CHECKLIST:
After configuration, always verify:
1. ✅ \`jules_session_info\` shows correct mode
2. ✅ \`hasBrowserbaseConfig\` or \`hasUserDataDir\` as appropriate
3. ✅ Test task creation works without authentication prompts

### USER EXPERIENCE OPTIMIZATION:
- Ask contextual questions to understand their workflow
- Provide specific commands they can copy-paste
- Test configuration immediately after setup
- Offer fallback options if primary choice fails`
            }]
          };
        case 'jules://troubleshooting/authentication':
          return {
            contents: [{
              uri,
              mimeType: 'text/plain',
              text: `# Automated Authentication Troubleshooting

## Agent Diagnostic and Repair Instructions

When users report authentication issues, follow this systematic troubleshooting process:

### STEP 1: Gather Diagnostic Information
Run these commands to assess the situation:

1. **Check Session Configuration:**
   \`jules_session_info\`

   Look for:
   - \`sessionMode\`: Current mode
   - \`browserConnected\`: Should be true
   - \`pageReady\`: Should be true
   - Configuration flags for chosen mode

2. **Take Screenshot:**
   \`jules_screenshot\`

   This shows what the browser actually sees

### STEP 2: Common Issue Patterns

**Pattern: "Browser not connected"**
- Symptom: \`browserConnected: false\`
- Cause: Browser launch failure
- Fix: Check environment variables, restart MCP

**Pattern: "Authentication required"**
- Symptom: Screenshot shows Google login page
- Cause: Session expired or not configured
- Fix: Re-authenticate or refresh session

**Pattern: "Permission denied"**
- Symptom: Access denied errors in task creation
- Cause: Insufficient Google account permissions
- Fix: Check Jules access permissions

**Pattern: "Browserbase connection failed"**
- Symptom: Network errors with browserbase mode
- Cause: Invalid API credentials or network issues
- Fix: Verify Browserbase credentials

### STEP 3: Mode-Specific Troubleshooting

**Chrome Profile Issues:**
1. Verify profile path exists
2. Check Chrome isn't running (conflicts with automation)
3. Ensure profile has Google authentication

**Cookie Issues:**
1. Check cookie format and validity
2. Verify cookies aren't expired
3. Re-extract fresh cookies if needed

**Browserbase Issues:**
1. Verify API key and project ID
2. Check network connectivity
3. Create new session if existing one is corrupted

**Persistent Mode Issues:**
1. Check browser data directory permissions
2. Clear corrupted browser data if needed
3. Restart with fresh persistent directory

### STEP 4: Progressive Repair Strategy

Try fixes in this order:

1. **Quick Fix:**
   - Restart MCP server
   - Use \`jules_session_info\` to verify restart

2. **Session Refresh:**
   - Clear current session data
   - Re-authenticate with chosen method

3. **Configuration Reset:**
   - Switch to 'fresh' mode temporarily
   - Test basic functionality
   - Reconfigure preferred mode

4. **Environment Validation:**
   - Verify all environment variables
   - Test with minimal configuration
   - Gradually add complexity

### STEP 5: Automated Repair Commands

**Reset Session:**
\`\`\`
# Clear browser data and restart
jules_session_info  # Check current state
jules_screenshot    # See what browser shows
\`\`\`

**Re-extract Cookies:**
\`\`\`
# If using cookie mode
jules_get_cookies   # Extract current cookies
jules_set_cookies   # Apply fresh cookies
\`\`\`

**Test Connectivity:**
\`\`\`
# Minimal test to verify authentication
jules_list_tasks    # Should work without errors
\`\`\`

### STEP 6: Escalation Path

If basic troubleshooting fails:
1. Switch to \`SESSION_MODE=fresh\` for immediate testing
2. Guide manual authentication for urgent tasks
3. Document exact error messages and configuration
4. Recommend Browserbase mode for persistent solution

### PREVENTION:
- Monitor session health with periodic \`jules_session_info\` calls
- Set up automated cookie refresh if using cookie mode
- Use Browserbase for production deployments to avoid local issues

Remember: Always start with \`jules_session_info\` and \`jules_screenshot\` to understand the current state before attempting fixes.`
            }]
          };
        default:
          throw new McpError(ErrorCode.InvalidRequest, `Unknown resource: ${uri}`);
      }
    });
  }

  // Browserbase session management
  private async createBrowserbaseSession(): Promise<BrowserbaseSession> {
    if (!this.config.browserbaseApiKey || !this.config.browserbaseProjectId) {
      throw new Error('Browserbase API key and project ID are required for browserbase mode');
    }

    const sessionData: any = {
      projectId: this.config.browserbaseProjectId,
      keepAlive: true,
      timeout: this.config.timeout,
    };

    // Add context ID if available for persistent sessions with Chrome user data
    const contextId = process.env.BROWSERBASE_CONTEXT_ID;
    if (contextId) {
      // Try different parameter names based on API documentation
      sessionData.contextId = contextId;
      console.error(`Using Browserbase context: ${contextId}`);
    }

    try {
      const response = await axios.post(
        `https://api.browserbase.com/v1/sessions`,
        sessionData,
        {
          headers: {
            'x-bb-api-key': this.config.browserbaseApiKey,
            'Content-Type': 'application/json',
          },
        }
      );

      return response.data;
    } catch (error: any) {
      // If context fails, try without context as fallback
      if (contextId && error.response?.status === 400) {
        console.error('Context parameter failed, trying without context...');
        delete sessionData.contextId;
        const response = await axios.post(
          `https://api.browserbase.com/v1/sessions`,
          sessionData,
          {
            headers: {
              'x-bb-api-key': this.config.browserbaseApiKey,
              'Content-Type': 'application/json',
            },
          }
        );
        return response.data;
      }
      throw error;
    }
  }

  private async getBrowserbaseConnectUrl(): Promise<string> {
    if (this.config.browserbaseSessionId) {
      // Use existing session
      return `wss://connect.browserbase.com?apiKey=${this.config.browserbaseApiKey}&sessionId=${this.config.browserbaseSessionId}`;
    } else {
      // Create new session
      const session = await this.createBrowserbaseSession();
      console.error(`Created Browserbase session: ${session.id}`);
      return session.connectUrl;
    }
  }

  // Cookie management - Fixed parsing
  private parseCookiesFromString(cookieString: string): Array<{name: string, value: string, domain: string}> {
    const cookies: Array<{name: string, value: string, domain: string}> = [];

    // Split by semicolon and process each cookie
    const parts = cookieString.split(';');

    for (let i = 0; i < parts.length; i++) {
      const part = parts[i].trim();

      // Skip domain specifications
      if (part.startsWith('domain=')) {
        continue;
      }

      // Parse name=value pairs
      const equalIndex = part.indexOf('=');
      if (equalIndex > 0) {
        const name = part.substring(0, equalIndex).trim();
        const value = part.substring(equalIndex + 1).trim();

        if (name && value) {
          cookies.push({
            name,
            value,
            domain: '.google.com'
          });
        }
      }
    }

    console.error(`Parsed ${cookies.length} cookies from string`);
    return cookies;
  }

  private async loadCookiesFromFile(cookiePath: string): Promise<Array<{name: string, value: string, domain: string}>> {
    try {
      const cookieData = await fs.readFile(cookiePath, 'utf-8');
      return JSON.parse(cookieData);
    } catch (error) {
      console.error(`Failed to load cookies from ${cookiePath}:`, error);
      return [];
    }
  }

  private async saveCookiesToFile(cookies: Array<{name: string, value: string, domain: string}>, cookiePath: string): Promise<void> {
    try {
      await fs.mkdir(path.dirname(cookiePath), { recursive: true });
      await fs.writeFile(cookiePath, JSON.stringify(cookies, null, 2));
    } catch (error) {
      console.error(`Failed to save cookies to ${cookiePath}:`, error);
    }
  }

  // Browser management with comprehensive session support
  private async getBrowser(): Promise<Browser> {
    if (!this.browser) {
      switch (this.config.sessionMode) {
        case 'browserbase':
          const connectUrl = await this.getBrowserbaseConnectUrl();
          this.browser = await chromium.connectOverCDP(connectUrl);
          break;

        case 'chrome-profile':
          if (!this.config.userDataDir) {
            throw new Error('CHROME_USER_DATA_DIR must be set for chrome-profile mode');
          }
          // For persistent contexts, we'll handle this differently in getPage
          this.browser = await chromium.launch({
            headless: this.config.headless,
            timeout: this.config.timeout
          });
          break;

        case 'persistent':
          // For persistent contexts, we'll handle this differently in getPage
          this.browser = await chromium.launch({
            headless: this.config.headless,
            timeout: this.config.timeout
          });
          break;

        case 'cookies':
        case 'fresh':
        default:
          this.browser = await chromium.launch({
            headless: this.config.headless,
            timeout: this.config.timeout
          });
          break;
      }
    }
    return this.browser;
  }

  private async getPage(): Promise<Page> {
    if (!this.page) {
      // Handle persistent contexts separately
      if (this.config.sessionMode === 'chrome-profile' && this.config.userDataDir) {
        const context = await chromium.launchPersistentContext(this.config.userDataDir, {
          headless: this.config.headless,
          timeout: this.config.timeout,
        });
        const pages = context.pages();
        this.page = pages.length > 0 ? pages[0] : await context.newPage();
      } else if (this.config.sessionMode === 'persistent') {
        const persistentDir = this.config.userDataDir || path.join(os.homedir(), '.jules-mcp', 'browser-data');
        const context = await chromium.launchPersistentContext(persistentDir, {
          headless: this.config.headless,
          timeout: this.config.timeout,
        });
        const pages = context.pages();
        this.page = pages.length > 0 ? pages[0] : await context.newPage();
      } else {
        const browser = await this.getBrowser();

        if (this.config.sessionMode === 'browserbase') {
          // For Browserbase, get existing pages or create new one
          const contexts = browser.contexts();
          if (contexts.length > 0) {
            const pages = contexts[0].pages();
            this.page = pages.length > 0 ? pages[0] : await contexts[0].newPage();
          } else {
            this.page = await browser.newPage();
          }
        } else {
          this.page = await browser.newPage();
        }
      }

      await this.page.setViewportSize({ width: 1200, height: 800 });

      // Load cookies if specified
      await this.loadSessionCookies();
    }
    return this.page;
  }

  private async loadSessionCookies(): Promise<void> {
    if (!this.page) return;

    let cookies: Array<{name: string, value: string, domain: string}> = [];

    // Load cookies from string
    if (this.config.googleAuthCookies) {
      cookies = this.parseCookiesFromString(this.config.googleAuthCookies);
      console.error(`Loaded ${cookies.length} cookies from environment variable`);
    }
    // Load cookies from file
    else if (this.config.cookiePath && this.config.sessionMode === 'cookies') {
      cookies = await this.loadCookiesFromFile(this.config.cookiePath);
      console.error(`Loaded ${cookies.length} cookies from file`);
    }

    // Set cookies if any were loaded
    if (cookies.length > 0) {
      await this.page.context().addCookies(cookies.map(cookie => ({
        name: cookie.name,
        value: cookie.value,
        domain: cookie.domain,
        path: '/',
      })));
      console.error(`Set ${cookies.length} cookies in browser context`);
    }
  }

  private async saveSessionCookies(): Promise<void> {
    if (!this.page || !this.config.cookiePath || this.config.sessionMode !== 'cookies') return;

    try {
      const cookies = await this.page.context().cookies();
      const simplifiedCookies = cookies.map(cookie => ({
        name: cookie.name,
        value: cookie.value,
        domain: cookie.domain
      }));
      await this.saveCookiesToFile(simplifiedCookies, this.config.cookiePath);
      console.error(`Saved ${cookies.length} cookies to file`);
    } catch (error) {
      console.error('Failed to save cookies:', error);
    }
  }

  // Data persistence
  private async loadTaskData(): Promise<{ tasks: JulesTask[] }> {
    try {
      const data = await fs.readFile(this.dataPath, 'utf-8');
      return JSON.parse(data);
    } catch (error) {
      if ((error as any).code === 'ENOENT') {
        return { tasks: [] };
      }
      throw error;
    }
  }

  private async saveTaskData(data: { tasks: JulesTask[] }): Promise<void> {
    await fs.mkdir(path.dirname(this.dataPath), { recursive: true });
    await fs.writeFile(this.dataPath, JSON.stringify(data, null, 2));
  }

  // Task ID extraction
  private extractTaskId(taskIdOrUrl: string): string {
    if (taskIdOrUrl.includes('jules.google.com/task/')) {
      const match = taskIdOrUrl.match(/\/task\/([^/]+)/);
      return match ? match[1] : taskIdOrUrl;
    }
    return taskIdOrUrl;
  }

  private async resolveJulesCliPath(): Promise<string> {
    const cliPath = this.config.julesCliPath || "jules";
    const execPromise = promisify(exec);

    // 1. Try "jules" directly (check PATH)
    try {
      const checkCmd = os.platform() === 'win32' ? 'where jules' : 'which jules';
      await execPromise(checkCmd);
      return "jules";
    } catch (e) {
      // Not in path
    }

    // 2. Try configured path
    if (this.config.julesCliPath) {
      try {
        const checkCmd = os.platform() === 'win32' ? `where "${this.config.julesCliPath}"` : `ls "${this.config.julesCliPath}"`;
        await execPromise(checkCmd);
        return this.config.julesCliPath;
      } catch (e) {
        // Configured path invalid
      }
    }

    // 3. Fallback to common absolute path if on Windows
    if (os.platform() === 'win32') {
      const fallbackPath = path.join(os.homedir(), 'AppData', 'Roaming', 'npm', 'jules.cmd');
      try {
        await fs.access(fallbackPath);
        return fallbackPath;
      } catch (e) {
        // Fallback invalid
      }
    }

    return "jules"; // Ultimate fallback
  }

  private async runJulesCli(args: string[]): Promise<string> {
    const execPromise = promisify(exec);
    const cliPath = await this.resolveJulesCliPath();

    // Safely wrap and escape arguments for the shell
    const escapedArgs = args.map(arg => {
      // For Windows, wrap in double quotes and escape internal double quotes
      if (os.platform() === 'win32') {
        const escaped = arg.replace(/"/g, '""');
        return `"${escaped}"`;
      } else {
        // For POSIX, wrap in single quotes and handle internal single quotes
        const escaped = arg.replace(/'/g, "'\\''");
        return `'${escaped}'`;
      }
    });

    const command = `${cliPath} ${escapedArgs.join(" ")} < /dev/null`;

    try {
      console.error(`Executing Jules CLI: ${command}`);
      const { stdout, stderr } = await execPromise(command);
      if (stderr && !stdout) {
        return stderr;
      }
      return stdout;
    } catch (error: any) {
      throw new Error(`Jules CLI Error: ${error.message}`);
    }
  }

  private async runGitCommand(args: string[]): Promise<string> {
    const execPromise = promisify(exec);
    const command = `git ${args.join(" ")}`;
    try {
      console.error(`Executing Git command: ${command}`);
      const { stdout } = await execPromise(command);
      return stdout.trim();
    } catch (error: any) {
      throw new Error(`Git Error: ${error.message}`);
    }
  }

  private async detectGitContext() {
    try {
      // Get remote URL to extract owner/repo
      const remoteUrl = await this.runGitCommand(["remote", "get-url", "origin"]);
      // Matches both ssh and https formats
      const repoMatch = remoteUrl.match(/[:/]([^/]+\/[^/.]+)(\.git)?$/);
      const repository = repoMatch ? repoMatch[1] : undefined;

      // Get current branch
      const branch = await this.runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"]);

      return { repository, branch };
    } catch (e) {
      return { repository: undefined, branch: undefined };
    }
  }

  private async initiateDelegation(args: any) {
    let { repository, branch, marker = "@jules", pushFirst = true } = args;

    // Auto-detect context if missing
    if (!repository || !branch) {
      const detected = await this.detectGitContext();
      repository = repository || detected.repository;
      branch = branch || detected.branch;
    }

    if (!repository || !branch) {
      throw new Error("Repository and branch must be provided or auto-detectable via local Git context.");
    }

    let results = [];

    // Step 1: Push if requested
    if (pushFirst) {
      try {
        console.error(`Pushing branch ${branch} to origin...`);
        await this.runGitCommand(["push", "origin", branch]);
        results.push(`✓ Pushed ${branch} to origin successfully.`);
      } catch (error: any) {
        results.push(`⚠ Push might have failed or skip: ${error.message}`);
      }
    }

    // Step 2: Initiate Jules Task
    // Prompt specifically designed for delegated tasks
    const prompt = `I have added code markers starting with '${marker}' in this branch. Please scan the repository, find these markers, and implement the requested changes for each one. Once found, remove the markers as you implement the fixes.`;

    try {
      let taskResult;
      // REST API is more reliable for direct prompts
      if (this.config.julesApiKey) {
        taskResult = await this.createTaskViaApi({
          description: prompt,
          repository,
          branch,
          type: "delegated",
          marker
        });
        results.push(`✓ Jules task initiated via REST API.`);
      } else {
        // Fallback to CLI
        taskResult = await this.createTaskViaCli({
          description: prompt,
          repository,
          type: "delegated",
          marker
        });
        results.push(`✓ Jules task initiated via CLI (Note: CLI may use default branch unless remote VM is pre-synced).`);
      }

      return {
        content: [
          {
            type: "text",
            text: `Delegation Initiation Results:\n\n${results.join("\n")}\n\nJules is now scanning your branch for '${marker}' markers.`
          }
        ]
      };
    } catch (error: any) {
      throw new Error(`Failed to initiate Jules delegation: ${error.message}`);
    }
  }

  private async getLatestAgentMessage(sessionId: string): Promise<string | undefined> {
    if (!this.config.julesApiKey) return undefined;

    try {
      const response = await axios.get(
        `https://jules.googleapis.com/v1alpha/sessions/${sessionId}/activities?pageSize=10`,
        {
          headers: { "x-goog-api-key": this.config.julesApiKey }
        }
      );

      const activities = response.data.activities || [];
      // Find latest agent message
      const agentMsg = activities.find((a: any) => a.agentMessaged);
      return agentMsg ? agentMsg.agentMessaged.prompt : undefined;
    } catch (e) {
      console.error(`Failed to get latest agent message for ${sessionId}:`, e);
      return undefined;
    }
  }

  private async checkFeedback(args: any) {
    let { repository } = args;

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for feedback monitoring.");
    }

    // Auto-detect repository if not provided
    if (!repository) {
      const detected = await this.detectGitContext();
      repository = detected.repository;
    }

    const data = await this.loadTaskData();
    const activeTasks = data.tasks.filter(t =>
      t.status === 'pending' || t.status === 'in_progress'
    );

    const feedbackNeeded = [];

    for (const task of activeTasks) {
      if (repository && task.repository.toLowerCase() !== repository.toLowerCase()) continue;

      try {
        const response = await axios.get(
          `https://jules.googleapis.com/v1alpha/sessions/${task.id}`,
          {
            headers: { "x-goog-api-key": this.config.julesApiKey }
          }
        );

        if (response.data.state === 'AWAITING_USER_FEEDBACK') {
          const question = await this.getLatestAgentMessage(task.id);
          feedbackNeeded.push({
            taskId: task.id,
            repository: task.repository,
            branch: task.branch,
            question: question || "Jules is awaiting feedback, but no message was found."
          });
        }
      } catch (e) {
        console.error(`Check feedback failed for task ${task.id}:`, e);
      }
    }

    if (feedbackNeeded.length === 0) {
      return {
        content: [{ type: "text", text: "No sessions currently require user feedback." }]
      };
    }

    const report = feedbackNeeded.map(f =>
      `### Task ${f.taskId} (${f.repository})\n` +
      `**Branch**: ${f.branch}\n` +
      `**Jules Question**:\n> ${f.question}\n`
    ).join('\n---\n');

    return {
      content: [{ type: "text", text: `# Feedback Required\n\n${report}` }]
    };
  }

  private async createTaskViaApi(args: any) {
    const { description, repository, branch = "main", type = "standard", marker } = args;

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for API-based task creation");
    }

    try {
      console.error(`Creating ${type} task via API for ${repository}...`);

      const response = await axios.post(
        "https://jules.googleapis.com/v1alpha/sessions",
        {
          prompt: description,
          sourceContext: {
            source: `sources/github/${repository}`,
            githubRepoContext: {
              startingBranch: branch
            }
          },
          title: description.slice(0, 50) + (description.length > 50 ? "..." : ""),
          requirePlanApproval: true
        },
        {
          headers: {
            "x-goog-api-key": this.config.julesApiKey,
            "Content-Type": "application/json"
          }
        }
      );

      const session = response.data;
      const taskId = session.id || session.name.split("/").pop();
      const url = `https://jules.google.com/task/${taskId}`;

      // Create task object for local tracking
      const task: JulesTask = {
        id: taskId,
        title: session.title || description.slice(0, 50),
        description,
        repository,
        branch,
        status: "pending",
        type,
        marker,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        url,
        chatHistory: [],
        sourceFiles: []
      };

      // Save to data
      const data = await this.loadTaskData();
      data.tasks.push(task);
      await this.saveTaskData(data);

      return {
        taskId,
        task,
        content: [
          {
            type: "text",
            text: `Task created successfully via API!\n\nTask ID: ${taskId}\nRepository: ${repository}\nBranch: ${branch}\nURL: ${url}\n\nJules is now analyzing the task.`
          }
        ]
      };
    } catch (error: any) {
      const errorDetail = error.response?.data ? JSON.stringify(error.response.data) : error.message;
      throw new Error(`API Task Creation Failed: ${errorDetail}`);
    }
  }

  private async sendMessageViaApi(args: any) {
    const { taskId, message } = args;
    const actualTaskId = this.extractTaskId(taskId);

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for API-based messages");
    }

    try {
      console.error(`Sending message to session ${actualTaskId} via API...`);

      await axios.post(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}:sendMessage`,
        {
          prompt: message
        },
        {
          headers: {
            "x-goog-api-key": this.config.julesApiKey,
            "Content-Type": "application/json"
          }
        }
      );

      return {
        content: [
          {
            type: "text",
            text: `Message sent successfully to Jules session ${actualTaskId} via API.`
          }
        ]
      };
    } catch (error: any) {
      const errorDetail = error.response?.data ? JSON.stringify(error.response.data) : error.message;
      throw new Error(`API Message Sending Failed: ${errorDetail}`);
    }
  }

  private async approvePlanViaApi(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for API-based approval");
    }

    try {
      console.error(`Approving plan for session ${actualTaskId} via API...`);

      await axios.post(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}:approvePlan`,
        {},
        {
          headers: {
            "x-goog-api-key": this.config.julesApiKey,
            "Content-Type": "application/json"
          }
        }
      );

      return {
        content: [
          {
            type: "text",
            text: `Plan approved successfully for Jules session ${actualTaskId} via API.`
          }
        ]
      };
    } catch (error: any) {
      const errorDetail = error.response?.data ? JSON.stringify(error.response.data) : error.message;
      throw new Error(`API Plan Approval Failed: ${errorDetail}`);
    }
  }

  private async resumeTaskViaApi(args: any) {
    const { taskId } = args;
    const message = "Please resume the task.";
    return await this.sendMessageViaApi({ taskId, message });
  }

  private async createTask(args: any) {
    // PREFERRED: Jules CLI
    try {
      return await this.createTaskViaCli(args);
    } catch (error) {
      console.error(`CLI createTask failed: ${error}`);
    }

    // SECONDARY: Jules REST API
    if (this.config.julesApiKey) {
      try {
        return await this.createTaskViaApi(args);
      } catch (error) {
        console.error(`API createTask failed: ${error}`);
      }
    }

    // LAST RESORT: Browser Fallback
    return await this.createTaskViaBrowser(args);
  }

  private async createTaskViaCli(args: any) {
    const { description, repository, branch = "main", type = "standard", marker } = args;
    // Command: jules remote new --repo "octocat/repo" --session "Task Description" < /dev/null
    const cliOutput = await this.runJulesCli([
      "remote", "new",
      "--repo", repository,
      "--session", description
    ]);

    // Heuristic: Extract Session ID from CLI output
    // Assuming output contains something like "Created session: 12345" or raw ID
    const taskIdMatch = cliOutput.match(/([a-f0-9-]{8,})/i);
    const taskId = taskIdMatch ? taskIdMatch[1] : `cli-${Date.now()}`;
    const url = `https://jules.google.com/task/${taskId}`;

    // Create task object for local tracking
    const task: JulesTask = {
      id: taskId,
      title: description.slice(0, 50) + (description.length > 50 ? '...' : ''),
      description,
      repository,
      branch,
      status: 'pending',
      type,
      marker,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      url,
      chatHistory: [],
      sourceFiles: []
    };

    // Save to data
    const data = await this.loadTaskData();
    data.tasks.push(task);
    await this.saveTaskData(data);

    return {
      taskId,
      task,
      content: [
        {
          type: "text",
          text: `Task creation initiated via CLI:\n\n${cliOutput}\n\nSession ID Captured: ${taskId}\nNote: Check jules_list_tasks to monitor its progress.`
        }
      ]
    };
  }

  private async createTaskViaBrowser(args: any) {
    const { description, repository, branch = 'main', type = 'standard', marker } = args;
    const page = await this.getPage();

    try {
      // Navigate to Jules task creation
      await page.goto(`${this.config.baseUrl}/task`);
      await page.waitForLoadState('networkidle');

      // Click new task button if needed
      const newTaskButton = page.locator('button.mat-mdc-tooltip-trigger svg');
      if (await newTaskButton.isVisible()) {
        await newTaskButton.click();
      }

      // Repository selection
      await page.locator("div.repo-select div.header-container").click();
      await page.locator("div.repo-select input").fill(repository);
      await page.locator("div.repo-select div.opt-list > swebot-option").first().click();

      // Branch selection
      await page.locator("div.branch-select div.header-container > div").click();

      // Try to find specific branch or select first available
      const branchOptions = page.locator("div.branch-select swebot-option");
      const branchCount = await branchOptions.count();
      if (branchCount > 0) {
        await branchOptions.first().click();
      }

      // Task description
      await page.locator("textarea").fill(description);
      await page.keyboard.press('Enter');

      // Submit
      await page.locator("div.chat-container button:nth-of-type(2)").click();

      // Wait for task creation and get URL
      await page.waitForURL('**/task/**');
      const url = page.url();
      const taskId = this.extractTaskId(url);

      // Create task object
      const task: JulesTask = {
        id: taskId,
        title: description.slice(0, 50) + (description.length > 50 ? '...' : ''),
        description,
        repository,
        branch,
        status: 'pending',
        type,
        marker,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        url,
        chatHistory: [],
        sourceFiles: []
      };

      // Save to data
      const data = await this.loadTaskData();
      data.tasks.push(task);
      await this.saveTaskData(data);

      return {
        taskId,
        task,
        content: [
          {
            type: 'text',
            text: `Task created successfully!\n\nTask ID: ${taskId}\nRepository: ${repository}\nBranch: ${branch}\nDescription: ${description}\nURL: ${url}\n\nTask is now pending Jules' analysis. You can check progress with jules_get_task.`
          }
        ]
      };
    } catch (error) {
      throw new Error(`Failed to create task: ${error}`);
    }
  }

  private async getTask(args: any) {
    if (this.config.julesApiKey) {
      try {
        return await this.getTaskViaApi(args);
      } catch (error) {
        console.error(`API getTask failed, falling back to browser: ${error}`);
      }
    }
    return await this.getTaskViaBrowser(args);
  }

  private async getTaskViaApi(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for API-based task details");
    }

    try {
      console.error(`Getting task ${actualTaskId} via API...`);

      const response = await axios.get(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}`,
        {
          headers: {
            "x-goog-api-key": this.config.julesApiKey
          }
        }
      );

      const session = response.data;
      const latestMessage = session.state === 'AWAITING_USER_FEEDBACK' ?
        await this.getLatestAgentMessage(actualTaskId) : undefined;

      return {
        content: [
          {
            type: "text",
            text: `Task Details (${actualTaskId}) via API:\n\n` +
                  `Title: ${session.title}\n` +
                  `State: ${session.state}` +
                  (latestMessage ? `\n\nJULES QUESTION:\n${latestMessage}` : "") +
                  `\n\nNote: Detailed chat history and file diffs may require browser or activity list.`
          }
        ]
      };
    } catch (error: any) {
      throw new Error(`API Get Task Failed: ${error.message}`);
    }
  }

  private async getTaskViaBrowser(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);
    const page = await this.getPage();

    try {
      // Navigate to task
      const url = taskId.includes('jules.google.com') ? taskId : `${this.config.baseUrl}/task/${actualTaskId}`;
      await page.goto(url);
      await page.waitForLoadState('networkidle');

      // Extract task information
      const taskData = await page.evaluate(() => {
        // Extract chat messages
        const chatMessages = Array.from(document.querySelectorAll('div.chat-content')).map(el => ({
          content: el.textContent?.trim() || '',
          timestamp: new Date().toISOString(),
          type: 'system' as const
        }));

        // Extract source files
        const sourceFiles = Array.from(document.querySelectorAll('div.source-content a')).map(link => ({
          filename: link.textContent?.trim() || '',
          url: link.getAttribute('href') || '',
          status: 'modified' as const
        }));

        // Extract task status
        const statusEl = document.querySelector('.task-status, [data-status], .status');
        const status = statusEl?.textContent?.toLowerCase() || 'unknown';

        return {
          chatMessages,
          sourceFiles,
          status
        };
      });

      // Update local data
      const data = await this.loadTaskData();
      let task = data.tasks.find(t => t.id === actualTaskId);

      if (task) {
        task.chatHistory = taskData.chatMessages;
        task.sourceFiles = taskData.sourceFiles;
        task.updatedAt = new Date().toISOString();
        await this.saveTaskData(data);
      }

      return {
        content: [
          {
            type: 'text',
            text: `Task Details (${actualTaskId}):\n\n` +
                  `Status: ${taskData.status}\n` +
                  `URL: ${url}\n` +
                  `Source Files (${taskData.sourceFiles.length}):\n` +
                  taskData.sourceFiles.map((f: any) => `  - ${f.filename}`).join('\n') +
                  `\n\nRecent Chat Messages (${taskData.chatMessages.length}):\n` +
                  taskData.chatMessages.slice(-3).map(m => `  - ${m.content.slice(0, 100)}...`).join('\n')
          }
        ]
      };
    } catch (error) {
      throw new Error(`Failed to get task: ${error}`);
    }
  }

  private async sendMessage(args: any) {
    if (this.config.julesApiKey) {
      try {
        return await this.sendMessageViaApi(args);
      } catch (error) {
        console.error(`API sendMessage failed, falling back to browser: ${error}`);
      }
    }
    return await this.sendMessageViaBrowser(args);
  }

  private async sendMessageViaBrowser(args: any) {
    const { taskId, message } = args;
    const actualTaskId = this.extractTaskId(taskId);
    const page = await this.getPage();

    try {
      const url = taskId.includes('jules.google.com') ? taskId : `${this.config.baseUrl}/task/${actualTaskId}`;
      await page.goto(url);
      await page.waitForLoadState('networkidle');

      // Send message
      await page.locator("div.bottom-bar-container textarea").fill(message);
      await page.keyboard.press('Enter');

      // Wait for response (brief)
      await page.waitForTimeout(2000);

      return {
        content: [
          {
            type: 'text',
            text: `Message sent to Jules task ${actualTaskId}: "${message}"\n\nJules is processing your request. Check back with jules_get_task to see the response.`
          }
        ]
      };
    } catch (error) {
      throw new Error(`Failed to send message: ${error}`);
    }
  }

  private async approvePlan(args: any) {
    if (this.config.julesApiKey) {
      try {
        return await this.approvePlanViaApi(args);
      } catch (error) {
        console.error(`API approvePlan failed: ${error}`);
      }
    }
    // Note: CLI doesn't seem to have a dedicated 'approve' command in remote mode
    // We could try 'jules remote pull --session ID --apply' as a way to "approve" and apply?
    // But the usage doc says 'remote pull' applies changes after Jules is done.
    // For now, fallback to browser.
    return await this.approvePlanViaBrowser(args);
  }

  private async approvePlanViaBrowser(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);
    const page = await this.getPage();

    try {
      const url = taskId.includes('jules.google.com') ? taskId : `${this.config.baseUrl}/task/${actualTaskId}`;
      await page.goto(url);
      await page.waitForLoadState('networkidle');

      // Look for approval button
      const approveButton = page.locator("div.approve-plan-container > button");
      if (await approveButton.isVisible()) {
        await approveButton.click();

        return {
          content: [
            {
              type: 'text',
              text: `Plan approved for task ${actualTaskId}. Jules will now execute the planned changes.`
            }
          ]
        };
      } else {
        return {
          content: [
            {
              type: 'text',
              text: `No plan approval needed for task ${actualTaskId}. The task may already be approved or not ready for approval yet.`
            }
          ]
        };
      }
    } catch (error) {
      throw new Error(`Failed to approve plan: ${error}`);
    }
  }

  private async resumeTask(args: any) {
    if (this.config.julesApiKey) {
      try {
        // Resume via API is basically sending a "resume" prompt if it's awaiting user feedback
        return await this.resumeTaskViaApi(args);
      } catch (error) {
        console.error(`API resumeTask failed, falling back to browser: ${error}`);
      }
    }
    return await this.resumeTaskViaBrowser(args);
  }

  private async resumeTaskViaBrowser(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);
    const page = await this.getPage();

    try {
      const url = taskId.includes('jules.google.com') ? taskId : `${this.config.baseUrl}/task/${actualTaskId}`;
      await page.goto(url);
      await page.waitForLoadState('networkidle');

      // Look for resume button
      const resumeButton = page.locator("div.resume-button-container svg");
      if (await resumeButton.isVisible()) {
        await resumeButton.click();

        return {
          content: [
            {
              type: 'text',
              text: `Task ${actualTaskId} resumed successfully. Jules will continue working on this task.`
            }
          ]
        };
      } else {
        return {
          content: [
            {
              type: 'text',
              text: `Task ${actualTaskId} doesn't appear to be paused or may already be active.`
            }
          ]
        };
      }
    } catch (error) {
      throw new Error(`Failed to resume task: ${error}`);
    }
  }

  private async listTasks(args: any) {
    // PREFERRED: Jules CLI
    try {
      const sessionInfo: any = await this.getSessionInfo({});
      if (sessionInfo.content[0].text.includes('"hasJulesCli": true')) {
        return await this.listTasksViaCli(args);
      }
    } catch (e) {
      // Fallback
    }

    // SECONDARY: Local Task Data (for tasks created via Browser/API that we track)
    let { status = 'all', limit = 10, repository } = args;

    // Auto-detect repository if not provided
    if (!repository) {
      const detected = await this.detectGitContext();
      repository = detected.repository;
    }

    const data = await this.loadTaskData();

    let filteredTasks = data.tasks;
    if (status !== 'all') {
      filteredTasks = data.tasks.filter(task => task.status === status);
    }

    if (repository) {
      filteredTasks = filteredTasks.filter(task => task.repository.toLowerCase() === repository.toLowerCase());
    }

    const tasks = filteredTasks.slice(0, limit);

    const taskList = tasks.map(task =>
      `${task.id}${task.type === 'delegated' ? ' [DELEGATED]' : ''} - ${task.title}\n` +
      `  Repository: ${task.repository}\n` +
      `  Branch: ${task.branch}\n` +
      `  Status: ${task.status}\n` +
      `  Created: ${new Date(task.createdAt).toLocaleDateString()}\n` +
      `  URL: ${task.url}\n`
    ).join('\n');

    return {
      content: [
        {
          type: 'text',
          text: `Jules Tasks for ${repository || 'all repositories'} (${tasks.length} of ${filteredTasks.length} total):\n\n${taskList || 'No tasks found.'}`
        }
      ]
    };
  }

  private async listTasksViaCli(args: any) {
    const { status = 'all' } = args;
    let cliArgs = ["remote", "list", "--session"];

    const output = await this.runJulesCli(cliArgs);
    return {
      content: [{ type: "text", text: `Jules CLI Task List:\n\n${output}` }]
    };
  }

  private async analyzeCode(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);

    // PREFERRED: API for activities and code artifacts
    if (this.config.julesApiKey) {
      try {
        return await this.analyzeCodeViaApi(args);
      } catch (error) {
        console.error(`API analyzeCode failed, trying CLI: ${error}`);
      }
    }

    // SECONDARY: CLI for status
    try {
      const sessionInfo: any = await this.getSessionInfo({});
      if (sessionInfo.content[0].text.includes('"hasJulesCli": true')) {
        return await this.analyzeCodeViaCli(args);
      }
    } catch (e) {
      // Fallback to browser
    }

    // LAST RESORT: Browser
    return await this.analyzeCodeViaBrowser(args);
  }

  private async analyzeCodeViaApi(args: any) {
    const { taskId, returnPatch = false } = args;
    const actualTaskId = this.extractTaskId(taskId);

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for API-based analysis");
    }

    try {
      console.error(`Analyzing code for session ${actualTaskId} via API...`);

      // Get activities to see what Jules has done
      const response = await axios.get(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}/activities?pageSize=20`,
        {
          headers: {
            "x-goog-api-key": this.config.julesApiKey
          }
        }
      );

      const activities = response.data.activities || [];
      const summary = activities.map((a: any) => {
        const type = Object.keys(a).find(k => k !== 'createTime' && k !== 'name' && k !== 'description') || 'activity';
        return `- ${type}: ${a.description || a[type]?.description || a[type]?.prompt || ""}`;
      }).join('\n');

      // Find ChangeSet artifacts to salvage code
      const changeSets = activities
        .filter((a: any) => a.changeSet)
        .map((a: any) => a.changeSet);

      let patchContent = "";
      if (changeSets.length > 0) {
        const latestPatch = changeSets[0]; // Activities are usually descending
        if (returnPatch) {
          patchContent = `\n\n--- FULL GIT PATCH ---\n${latestPatch.gitPatch}\n\n`;
        } else {
          patchContent = `\n\n--- LATEST CODE ARTIFACT ---\n` +
                        `Commit Message: ${latestPatch.suggestedCommitMessage || "N/A"}\n` +
                        `Patch Snippet (first 500 chars):\n${latestPatch.gitPatch.slice(0, 500)}...\n` +
                        `*Use returnPatch: true to get the full diff.*`;
        }
      }

      return {
        content: [
          {
            type: "text",
            text: `API Code Analysis for Session ${actualTaskId}:\n\nRecent Activities:\n${summary || "No activities found yet."}${patchContent}`
          }
        ]
      };
    } catch (error: any) {
      throw new Error(`API Code Analysis Failed: ${error.message}`);
    }
  }

  private async analyzeCodeViaBrowser(args: any) {
    const { taskId, includeSourceCode = false } = args;
    const actualTaskId = this.extractTaskId(taskId);
    const page = await this.getPage();

    try {
      const url = taskId.includes('jules.google.com') ? taskId : `${this.config.baseUrl}/task/${actualTaskId}`;
      await page.goto(url);
      await page.waitForLoadState('networkidle');

      // Extract code analysis information
      const codeData = await page.evaluate((includeSource) => {
        const sourceFiles = Array.from(document.querySelectorAll('div.source-content a')).map(link => ({
          filename: link.textContent?.trim() || '',
          url: link.getAttribute('href') || ''
        }));

        const codeChanges = Array.from(document.querySelectorAll('swebot-code-diff-update-card')).map(card => ({
          type: 'code-change',
          content: card.textContent?.trim() || ''
        }));

        return {
          sourceFiles,
          codeChanges,
          totalFiles: sourceFiles.length,
          totalChanges: codeChanges.length
        };
      }, includeSourceCode);

      const analysis = `Code Analysis for Task ${actualTaskId}:\n\n` +
                     `Total Files: ${codeData.totalFiles}\n` +
                     `Total Changes: ${codeData.totalChanges}\n\n` +
                     `Modified Files:\n${codeData.sourceFiles.map(f => `  - ${f.filename}`).join('\n')}\n\n` +
                     `Code Changes Summary:\n${codeData.codeChanges.map(c => `  - ${c.content.slice(0, 100)}...`).join('\n')}`;

      return {
        content: [
          {
            type: 'text',
            text: analysis
          }
        ]
      };
    } catch (error) {
      throw new Error(`Failed to analyze code: ${error}`);
    }
  }

  private async analyzeCodeViaCli(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);

    // Attempt to get status and diff via CLI
    const status = await this.runJulesCli(["task", "status", actualTaskId]);
    const diff = await this.runJulesCli(["task", "diff", actualTaskId]);

    return {
      content: [
        {
          type: "text",
          text: `Jules CLI Code Analysis for Task ${actualTaskId}:\n\n--- STATUS ---\n${status}\n\n--- DIFF ---\n${diff}`
        }
      ]
    };
  }

  private async generateAuditReport(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for audit reporting.");
    }

    try {
      console.error(`Generating audit report for ${actualTaskId}...`);

      // 1. Get Session Summary
      const sessionResponse = await axios.get(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}`,
        { headers: { "x-goog-api-key": this.config.julesApiKey } }
      );
      const session = sessionResponse.data;

      // 2. Get Activities
      const activitiesResponse = await axios.get(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}/activities?pageSize=50`,
        { headers: { "x-goog-api-key": this.config.julesApiKey } }
      );
      const activities = activitiesResponse.data.activities || [];

      // 3. Process Activities for Audit
      const events = activities.map((a: any) => {
        let eventType = "UNKNOWN";
        let detail = "";

        if (a.planGenerated) {
          eventType = "PLAN_GENERATED";
          detail = `Plan contains ${a.planGenerated.steps?.length || 0} steps.`;
        } else if (a.planApproved) {
          eventType = "PLAN_APPROVED";
        } else if (a.agentMessaged) {
          eventType = "JULES_MESSAGE";
          detail = a.agentMessaged.prompt;
        } else if (a.userMessaged) {
          eventType = "USER_MESSAGE";
          detail = a.userMessaged.prompt;
        } else if (a.changeSet) {
          eventType = "CODE_ARTIFACT";
          detail = `Produced patch: ${a.changeSet.suggestedCommitMessage || "No message"}`;
        } else if (a.sessionCompleted) {
          eventType = "COMPLETED";
        } else if (a.sessionFailed) {
          eventType = "FAILED";
          detail = a.sessionFailed.reason || "Unknown failure reason";
        } else if (a.progressUpdated) {
          eventType = "PROGRESS";
          detail = a.progressUpdated.description;
        } else {
          // Detect arbitrary event type from top-level key
          eventType = Object.keys(a).find(k => k !== 'createTime' && k !== 'name' && k !== 'description') || "ACTIVITY";
          detail = a.description || "No detail";
        }

        const safeDetail = (detail || "").replace(/\n/g, ' ');
        return `| ${new Date(a.createTime).toLocaleString()} | ${eventType} | ${safeDetail} |`;
      }).reverse();

      // 4. Identify Code Outcomes
      const patches = activities.filter((a: any) => a.changeSet).map((a: any) => a.changeSet);
      const outcomeText = patches.length > 0 ?
        `✅ Delivered ${patches.length} code checkpoint(s). Final patch salvaged: ${patches[0].suggestedCommitMessage}` :
        `❌ No code patches recorded in session history.`;

      // 5. Identify Most Recent Code Review
      const reviewText = this.extractCodeReviewFromActivities(activities);

      // 6. Construct Markdown Report
      const report = [
        `# 🛡️ Jules Session Audit Report`,
        `**Session ID**: \`${actualTaskId}\``,
        `**Title**: ${session.title}`,
        `**Final State**: \`${session.state}\``,
        `**Repository**: ${session.sourceContext?.source || "Unknown"}`,
        `**Generated At**: ${new Date().toLocaleString()}`,
        ``,
        `## 📝 Intent Statement (Initial Prompt)`,
        `> ${session.prompt || "No initial prompt record available."}`,
        ``,
        ...(reviewText ? [`## 🔍 Most Recent Code Review`, `> ${reviewText.replace(/\n/g, '\n> ')}`, ``] : []),
        `## 🔄 Delivery Activity Log`,
        `| Timestamp | Event Type | Details |`,
        `| :--- | :--- | :--- |`,
        ...events,
        ``,
        `## 🏁 Verification & Outcome`,
        outcomeText,
        ``,
        `**Audit Conclusion**: ${session.state === 'COMPLETED' ? "Successfully Delivered" : "Incomplete or Failed Delivery"}`,
        `---`,
        `*Report generated via Google Jules MCP Audit Tier.*`
      ].join('\n');

      return {
        content: [{ type: "text", text: report }]
      };
    } catch (error: any) {
      throw new Error(`Audit Report Generation Failed: ${error.message}`);
    }
  }

  private extractCodeReviewFromActivities(activities: any[]): string | undefined {
    // Search for PROGRESS activities that contain analysis/reasoning keywords
    const reviewActivity = activities.find(a => {
      const detail = a.progressUpdated?.description || a.description || "";
      return detail.includes("Analysis and Reasoning") ||
             detail.includes("Evaluation of the Solution") ||
             detail.includes("Merge Assessment") ||
             detail.includes("#Correct#") ||
             detail.includes("#Incomplete#");
    });

    return reviewActivity ? (reviewActivity.progressUpdated?.description || reviewActivity.description) : undefined;
  }

  private async getCodeReview(args: any) {
    const { taskId } = args;
    const actualTaskId = this.extractTaskId(taskId);

    if (!this.config.julesApiKey) {
      throw new Error("JULES_API_KEY is required for code review extraction.");
    }

    try {
      const activitiesResponse = await axios.get(
        `https://jules.googleapis.com/v1alpha/sessions/${actualTaskId}/activities?pageSize=50`,
        { headers: { "x-goog-api-key": this.config.julesApiKey } }
      );
      const activities = activitiesResponse.data.activities || [];
      const review = this.extractCodeReviewFromActivities(activities);

      if (review) {
        return {
          content: [
            {
              type: "text",
              text: `## 🔍 Latest Code Review for Session ${actualTaskId}\n\n${review}`
            }
          ]
        };
      } else {
        return {
          content: [
            {
              type: "text",
              text: `❌ No formal code review found in the session history for ${actualTaskId}.\n\n` +
                    `You can instruct Jules to perform a review by sending a message:\n` +
                    `"Please perform a final code review and provide a merge assessment."`
            }
          ]
        };
      }
    } catch (error: any) {
      throw new Error(`Failed to extract code review: ${error.message}`);
    }
  }


  private async bulkCreateTasks(args: any) {
    const { tasks } = args;
    const results = [];

    for (const taskData of tasks) {
      try {
        const result = await this.createTask(taskData);
        results.push(`✓ ${taskData.repository}: ${taskData.description.slice(0, 50)}...`);
      } catch (error) {
        results.push(`✗ ${taskData.repository}: Failed - ${error}`);
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: `Bulk Task Creation Results (${tasks.length} tasks):\n\n${results.join('\n')}`
        }
      ]
    };
  }

  private async takeScreenshot(args: any) {
    const { taskId, filename } = args;
    const page = await this.getPage();

    try {
      if (taskId) {
        const actualTaskId = this.extractTaskId(taskId);
        const url = taskId.includes('jules.google.com') ? taskId : `${this.config.baseUrl}/task/${actualTaskId}`;
        await page.goto(url);
        await page.waitForLoadState('networkidle');
      }

      const screenshotPath = filename || `jules-screenshot-${Date.now()}.png`;
      await page.screenshot({ path: screenshotPath, fullPage: true });

      return {
        content: [
          {
            type: 'text',
            text: `Screenshot saved to: ${screenshotPath}`
          }
        ]
      };
    } catch (error) {
      throw new Error(`Failed to take screenshot: ${error}`);
    }
  }

  private async getCookies(args: any) {
    const { format = 'json' } = args;
    const page = await this.getPage();

    try {
      const cookies = await page.context().cookies();

      if (format === 'string') {
        const cookieString = cookies.map(cookie =>
          `${cookie.name}=${cookie.value}; domain=${cookie.domain}; path=${cookie.path}`
        ).join('; ');

        return {
          content: [
            {
              type: 'text',
              text: `Cookie String:\\n${cookieString}`
            }
          ]
        };
      } else {
        return {
          content: [
            {
              type: 'text',
              text: `Cookies (${cookies.length} total):\\n${JSON.stringify(cookies, null, 2)}`
            }
          ]
        };
      }
    } catch (error) {
      throw new Error(`Failed to get cookies: ${error}`);
    }
  }

  private async setCookies(args: any) {
    const { cookies, format = 'json' } = args;
    const page = await this.getPage();

    try {
      let cookiesToSet: Array<{name: string, value: string, domain: string}> = [];

      if (format === 'string') {
        cookiesToSet = this.parseCookiesFromString(cookies);
      } else {
        const parsed = JSON.parse(cookies);
        cookiesToSet = Array.isArray(parsed) ? parsed : [parsed];
      }

      await page.context().addCookies(cookiesToSet.map(cookie => ({
        name: cookie.name,
        value: cookie.value,
        domain: cookie.domain,
        path: '/',
      })));

      // Save cookies if in cookies mode
      if (this.config.sessionMode === 'cookies' && this.config.cookiePath) {
        await this.saveCookiesToFile(cookiesToSet, this.config.cookiePath);
      }

      return {
        content: [
          {
            type: 'text',
            text: `Successfully set ${cookiesToSet.length} cookies. Session authentication should now work for Google Jules.`
          }
        ]
      };
    } catch (error) {
      throw new Error(`Failed to set cookies: ${error}`);
    }
  }

  private async getSessionInfo(args: any) {
    // Check if CLI is functional
    let hasJulesCli = false;
    let resolvedCliPath = "jules";
    try {
      resolvedCliPath = await this.resolveJulesCliPath();
      const execPromise = promisify(exec);
      await execPromise(`${resolvedCliPath} --version`);
      hasJulesCli = true;
    } catch (e) {
      // CLI not found or errored
    }

    const sessionInfo = {
      mcpVersion: "1.0.1-fixed",
      sessionMode: this.config.sessionMode,
      hasUserDataDir: !!this.config.userDataDir,
      hasCookiePath: !!this.config.cookiePath,
      hasGoogleAuthCookies: !!this.config.googleAuthCookies,
      hasBrowserbaseConfig: !!(this.config.browserbaseApiKey && this.config.browserbaseProjectId),
      browserbaseSessionId: this.config.browserbaseSessionId,
      hasJulesApiKey: !!this.config.julesApiKey,
      hasJulesCli,
      julesCliPath: resolvedCliPath,
      isHeadless: this.config.headless,
      timeout: this.config.timeout,
      baseUrl: this.config.baseUrl,
      dataPath: this.config.dataPath,
      browserConnected: !!this.browser,
      pageReady: !!this.page
    };

    return {
      content: [
        {
          type: 'text',
          text: `Jules MCP Session Info:\\n${JSON.stringify(sessionInfo, null, 2)}`
        }
      ]
    };
  }

  private async setupWizard(args: any) {
    const { environment = 'auto-detect', preferences = {} } = args;
    const { priority = 'ease-of-use', hasChrome = true, cloudDeployment = false } = preferences;

    // Auto-detect environment if requested
    let detectedEnv = environment;
    if (environment === 'auto-detect') {
      // Check for cloud environment indicators
      const isCloud = process.env.NODE_ENV === 'production' ||
                     process.env.SMITHERY_DEPLOYMENT === 'true' ||
                     !hasChrome;
      detectedEnv = isCloud ? 'cloud' : 'local';
    }

    // Intelligent recommendation based on environment and preferences
    let recommendation = '';
    let setupInstructions = '';
    let nextSteps = [];

    if (detectedEnv === 'cloud' || detectedEnv === 'smithery' || cloudDeployment) {
      recommendation = 'browserbase';
      setupInstructions = `
🌐 **RECOMMENDED: Browserbase Mode**

Perfect for cloud deployment! Here's why:
- ✅ No local browser dependencies
- ✅ Persistent Google sessions in the cloud
- ✅ Works on Smithery and other cloud platforms
- ✅ Zero local setup required

**Configuration:**
\`\`\`bash
SESSION_MODE=browserbase
BROWSERBASE_API_KEY=bb_live_g3i-b4WPFh__E3cErKE5rO-jWds
BROWSERBASE_PROJECT_ID=d718e85f-be7b-497d-9123-b1bbf798f1bb
\`\`\``;

      nextSteps = [
        'Read jules://prompts/browserbase-setup for detailed setup',
        'Use jules_session_info to verify configuration',
        'Test with jules_screenshot to see remote browser',
        'Create first task with jules_create_task'
      ];

    } else if (priority === 'ease-of-use' && hasChrome) {
      recommendation = 'chrome-profile';
      setupInstructions = `
🌍 **RECOMMENDED: Chrome Profile Mode**

Easiest setup for local development:
- ✅ Uses your existing Google Chrome login
- ✅ No manual cookie extraction needed
- ✅ Immediate authentication
- ✅ Most reliable for local development

**Configuration:**
\`\`\`bash
SESSION_MODE=chrome-profile
CHROME_USER_DATA_DIR=/Users/[username]/Library/Application Support/Google/Chrome/Default
\`\`\`

**Auto-detect your Chrome profile:**
\`find ~/Library/Application\\ Support/Google/Chrome -name "Default" -type d 2>/dev/null\``;

      nextSteps = [
        'Read jules://guides/session-modes for profile path detection',
        'Set CHROME_USER_DATA_DIR environment variable',
        'Use jules_session_info to verify configuration',
        'Test with jules_create_task to confirm authentication'
      ];

    } else if (priority === 'portability') {
      recommendation = 'cookies';
      setupInstructions = `
🍪 **RECOMMENDED: Cookie Mode**

Best for multi-machine portability:
- ✅ Works across different computers
- ✅ Cookies stored as environment variables
- ✅ No local browser dependencies
- ✅ Easy backup and restore

**Configuration:**
\`\`\`bash
SESSION_MODE=cookies
GOOGLE_AUTH_COOKIES="session_id=abc123; domain=.google.com; auth_token=xyz789; domain=.google.com"
COOKIES_PATH=~/.jules-mcp/cookies.json
\`\`\``;

      nextSteps = [
        'Read jules://prompts/cookie-extraction for step-by-step extraction',
        'Use jules_get_cookies to extract your current session',
        'Format cookies for GOOGLE_AUTH_COOKIES environment variable',
        'Test with jules_set_cookies and jules_session_info'
      ];

    } else {
      recommendation = 'persistent';
      setupInstructions = `
💾 **RECOMMENDED: Persistent Mode**

Maximum reliability and control:
- ✅ Full browser data persistence
- ✅ Complete control over authentication
- ✅ Reliable across restarts
- ✅ Local data security

**Configuration:**
\`\`\`bash
SESSION_MODE=persistent
CHROME_USER_DATA_DIR=~/.jules-mcp/browser-data
\`\`\``;

      nextSteps = [
        'Create browser data directory if needed',
        'Use jules_session_info to verify configuration',
        'Complete initial Google authentication',
        'Test persistence with multiple MCP restarts'
      ];
    }

    const wizardResponse = `# Jules MCP Setup Wizard Results

## Environment Analysis
- **Detected Environment**: ${detectedEnv}
- **User Priority**: ${priority}
- **Has Chrome Access**: ${hasChrome}
- **Cloud Deployment**: ${cloudDeployment}

${setupInstructions}

## Next Steps
${nextSteps.map((step, index) => `${index + 1}. ${step}`).join('\\n')}

## Quick Commands
- \`jules_session_info\` - Check current configuration
- \`jules_screenshot\` - Debug authentication state
- \`jules_create_task\` - Test end-to-end functionality

## Need Help?
- Read jules://prompts/session-setup for comprehensive automation guide
- Read jules://troubleshooting/authentication for common issues
- Use jules_setup_wizard again with different preferences to see alternatives

**Current Configuration Status:**
- Session Mode: ${this.config.sessionMode}
- Has Browserbase Config: ${!!(this.config.browserbaseApiKey && this.config.browserbaseProjectId)}
- Has Chrome Profile: ${!!this.config.userDataDir}
- Has Auth Cookies: ${!!this.config.googleAuthCookies}`;

    return {
      content: [
        {
          type: 'text',
          text: wizardResponse
        }
      ]
    };
  }

  private async getActiveTasks(): Promise<JulesTask[]> {
    const data = await this.loadTaskData();
    return data.tasks.filter(task =>
      task.status === 'in_progress' || task.status === 'pending'
    );
  }

  async cleanup() {
    // Save cookies before cleanup if in cookies mode
    await this.saveSessionCookies();

    if (this.page) {
      await this.page.close();
    }
    if (this.browser) {
      await this.browser.close();
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);

    if (this.config.debug) {
      console.error("Google Jules MCP Server running on stdio");
      console.error("Configuration:", {
        headless: this.config.headless,
        timeout: this.config.timeout,
        debug: this.config.debug,
        dataPath: this.config.dataPath
      });
    }
  }
}

// Handle process cleanup
if (process.env.NODE_ENV !== 'test') {
  process.on('SIGINT', async () => {
    console.error('Shutting down Jules MCP Server...');
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    console.error('Shutting down Jules MCP Server...');
    process.exit(0);
  });

  // Start the server
  const server = new GoogleJulesMCP();
  server.run().catch((error) => {
    console.error('Failed to start server:', error);
    process.exit(1);
  });
}
