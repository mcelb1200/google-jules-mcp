import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import axios from 'axios';
import { JCLAW } from '../src/index.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';

vi.mock('axios');
const mockedAxios = vi.mocked(axios);

describe('API Tier Tests', () => {
  let mcp: any;
  const tempDir = path.join(os.tmpdir(), 'jclaw-test-api');

  beforeEach(async () => {
    vi.stubEnv('NODE_ENV', 'test');
    vi.stubEnv('JULES_API_KEY', 'test-api-key');
    vi.stubEnv('JULES_DATA_PATH', path.join(tempDir, 'data.json'));

    await fs.mkdir(tempDir, { recursive: true });

    mcp = new JCLAW();
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('jules_create_task creates task via API successfully', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {
        id: 'test-session-id',
        title: 'Test Session',
        state: 'PENDING',
      },
    });

    const result = await mcp.createTaskViaApi({
      description: 'Fix the bug',
      repository: 'owner/repo',
      branch: 'main',
    });

    expect(mockedAxios.post).toHaveBeenCalledWith(
      'https://jules.googleapis.com/v1alpha/sessions',
      expect.objectContaining({
        prompt: 'Fix the bug',
        sourceContext: expect.objectContaining({
          source: 'sources/github/owner/repo',
        }),
      }),
      expect.objectContaining({
        headers: expect.objectContaining({
          'x-goog-api-key': 'test-api-key',
        }),
      })
    );
    expect(result.taskId).toBe('test-session-id');
    expect(result.content[0].text).toContain('Task created successfully via API!');
  });

  it('jules_get_task retrieves task details via API', async () => {
    mockedAxios.get.mockResolvedValueOnce({
      data: {
        name: 'sessions/test-session-id',
        title: 'Test Session',
        state: 'ACTIVE',
      },
    });

    const result = await mcp.getTaskViaApi({ taskId: 'test-session-id' });

    expect(mockedAxios.get).toHaveBeenCalledWith(
      'https://jules.googleapis.com/v1alpha/sessions/test-session-id',
      expect.objectContaining({
        headers: expect.objectContaining({
          'x-goog-api-key': 'test-api-key',
        }),
      })
    );
    expect(result.content[0].text).toContain('Task Details (test-session-id) via API:');
  });

  it('jules_send_message sends message via API', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {},
    });

    const result = await mcp.sendMessageViaApi({
      taskId: 'test-session-id',
      message: 'Hello Jules',
    });

    expect(mockedAxios.post).toHaveBeenCalledWith(
      'https://jules.googleapis.com/v1alpha/sessions/test-session-id:sendMessage',
      { prompt: 'Hello Jules' },
      expect.objectContaining({
        headers: expect.objectContaining({
          'x-goog-api-key': 'test-api-key',
        }),
      })
    );
    expect(result.content[0].text).toContain(
      'Message sent successfully to Jules session test-session-id via API.'
    );
  });

  it('jules_approve_plan approves plan via API', async () => {
    mockedAxios.post.mockResolvedValueOnce({
      data: {},
    });

    const result = await mcp.approvePlanViaApi({ taskId: 'test-session-id' });

    expect(mockedAxios.post).toHaveBeenCalledWith(
      'https://jules.googleapis.com/v1alpha/sessions/test-session-id:approvePlan',
      {},
      expect.objectContaining({
        headers: expect.objectContaining({
          'x-goog-api-key': 'test-api-key',
        }),
      })
    );
    expect(result.content[0].text).toContain(
      'Plan approved successfully for Jules session test-session-id via API.'
    );
  });
});
