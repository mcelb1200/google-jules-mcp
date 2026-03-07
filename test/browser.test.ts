import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { chromium } from 'playwright';
import { GoogleJulesMCP } from '../src/index.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';

vi.mock('playwright', () => ({
  chromium: {
    launch: vi.fn(),
    connectOverCDP: vi.fn(),
    launchPersistentContext: vi.fn(),
  }
}));

describe('Browser Tier Tests', () => {
  let mcp: any;
  let mockPage: any;
  let mockContext: any;
  let mockBrowser: any;
  const tempDir = path.join(os.tmpdir(), 'jclaw-test-browser');

  beforeEach(async () => {
    vi.stubEnv('NODE_ENV', 'test');
    vi.stubEnv('JULES_DATA_PATH', path.join(tempDir, 'data.json'));
    // Ensure we don't fall into CLI/API paths
    vi.stubEnv('JULES_API_KEY', '');
    vi.stubEnv('SESSION_MODE', 'fresh');

    await fs.mkdir(tempDir, { recursive: true });
    mcp = new GoogleJulesMCP();

    // Setup playwright mocks
    mockPage = {
      close: vi.fn().mockResolvedValue(true),
      goto: vi.fn().mockResolvedValue(true),
      waitForLoadState: vi.fn().mockResolvedValue(true),
      locator: vi.fn().mockReturnValue({
        isVisible: vi.fn().mockResolvedValue(true),
        click: vi.fn().mockResolvedValue(true),
        fill: vi.fn().mockResolvedValue(true),
        first: vi.fn().mockReturnValue({ click: vi.fn().mockResolvedValue(true) }),
        count: vi.fn().mockResolvedValue(1)
      }),
      keyboard: {
        press: vi.fn().mockResolvedValue(true)
      },
      waitForURL: vi.fn().mockResolvedValue(true),
      url: vi.fn().mockReturnValue('https://jules.google.com/task/browser-task-id'),
      setViewportSize: vi.fn().mockResolvedValue(true),
      context: vi.fn().mockReturnValue({
        addCookies: vi.fn().mockResolvedValue(true),
        cookies: vi.fn().mockResolvedValue([
            { name: 'sessionid', value: '123', domain: '.google.com' }
        ])
      }),
      evaluate: vi.fn().mockResolvedValue({
        chatMessages: [{ content: 'test message', type: 'system' }],
        sourceFiles: [{ filename: 'src/index.ts', status: 'modified' }],
        status: 'active'
      })
    };

    mockContext = {
      pages: vi.fn().mockReturnValue([mockPage]),
      newPage: vi.fn().mockResolvedValue(mockPage),
      addCookies: vi.fn().mockResolvedValue(true)
    };

    mockBrowser = {
      newPage: vi.fn().mockResolvedValue(mockPage),
      contexts: vi.fn().mockReturnValue([mockContext]),
      close: vi.fn().mockResolvedValue(true)
    };

    vi.mocked(chromium.launch).mockResolvedValue(mockBrowser);
  });

  afterEach(async () => {
    try {
      if (mcp) {
          await mcp.cleanup();
      }
    } catch (e) {}
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('jules_create_task via browser', async () => {
    // Override methods that would check API/CLI to force browser fallback
    mcp.createTaskViaCli = vi.fn().mockRejectedValue(new Error('CLI fail'));

    const result = await mcp.createTask({
      description: 'Browser task',
      repository: 'browser/repo'
    });

    expect(chromium.launch).toHaveBeenCalled();
    expect(mockPage.goto).toHaveBeenCalledWith('https://jules.google.com/task');
    expect(result.taskId).toBe('browser-task-id');
    expect(result.content[0].text).toContain('Task created successfully!');
  });

  it('jules_get_task via browser', async () => {
    const result = await mcp.getTask({ taskId: 'browser-task-id' });

    expect(mockPage.goto).toHaveBeenCalledWith('https://jules.google.com/task/browser-task-id');
    expect(mockPage.evaluate).toHaveBeenCalled();
    expect(result.content[0].text).toContain('Task Details (browser-task-id)');
    expect(result.content[0].text).toContain('src/index.ts');
  });

  it('jules_get_cookies returns parsed cookies', async () => {
      const result = await mcp.getCookies({ format: 'json' });
      expect(result.content[0].text).toContain('sessionid');
      expect(mockPage.context().cookies).toHaveBeenCalled();
  });

  it('jules_set_cookies adds cookies to context', async () => {
      const cookies = [{ name: 'testcookie', value: '123', domain: '.google.com' }];
      const result = await mcp.setCookies({ cookies: JSON.stringify(cookies), format: 'json' });

      expect(mockPage.context().addCookies).toHaveBeenCalledWith(
          expect.arrayContaining([
              expect.objectContaining({ name: 'testcookie', value: '123' })
          ])
      );
      expect(result.content[0].text).toContain('Successfully set 1 cookies');
  });
});
