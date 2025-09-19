"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GitService = void 0;
const child_process_1 = require("child_process");
const util_1 = require("util");
const execAsync = (0, util_1.promisify)(child_process_1.exec);
class GitService {
    constructor(workspacePath) {
        this.workspacePath = workspacePath || process.cwd();
    }
    async init() {
        try {
            await execAsync('git init', { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to initialize git repository: ${error}`);
        }
    }
    async clone(repoUrl, targetPath) {
        try {
            await execAsync(`git clone "${repoUrl}" "${targetPath}"`);
        }
        catch (error) {
            throw new Error(`Failed to clone repository: ${error}`);
        }
    }
    async add(files = ['.']) {
        try {
            const fileList = files.join(' ');
            await execAsync(`git add ${fileList}`, { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to add files: ${error}`);
        }
    }
    async commit(message) {
        try {
            await execAsync(`git commit -m "${message}"`, { cwd: this.workspacePath });
        }
        catch (error) {
            // Check if there are changes to commit
            const { stdout } = await execAsync('git status --porcelain', { cwd: this.workspacePath });
            if (!stdout.trim()) {
                throw new Error('No changes to commit');
            }
            throw new Error(`Failed to commit: ${error}`);
        }
    }
    async push(remote = 'origin', branch = 'main') {
        try {
            await execAsync(`git push ${remote} ${branch}`, { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to push: ${error}`);
        }
    }
    async pull(remote = 'origin', branch = 'main') {
        try {
            await execAsync(`git pull ${remote} ${branch}`, { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to pull: ${error}`);
        }
    }
    async status() {
        try {
            const { stdout } = await execAsync('git status --porcelain', { cwd: this.workspacePath });
            return stdout;
        }
        catch (error) {
            throw new Error(`Failed to get status: ${error}`);
        }
    }
    async log(limit = 10) {
        try {
            const { stdout } = await execAsync(`git log --oneline -${limit}`, { cwd: this.workspacePath });
            return stdout;
        }
        catch (error) {
            throw new Error(`Failed to get log: ${error}`);
        }
    }
    async getCurrentBranch() {
        try {
            const { stdout } = await execAsync('git branch --show-current', { cwd: this.workspacePath });
            return stdout.trim();
        }
        catch (error) {
            throw new Error(`Failed to get current branch: ${error}`);
        }
    }
    async createBranch(branchName) {
        try {
            await execAsync(`git checkout -b ${branchName}`, { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to create branch: ${error}`);
        }
    }
    async switchBranch(branchName) {
        try {
            await execAsync(`git checkout ${branchName}`, { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to switch branch: ${error}`);
        }
    }
    async getRemotes() {
        try {
            const { stdout } = await execAsync('git remote', { cwd: this.workspacePath });
            return stdout.trim().split('\n').filter(remote => remote.trim());
        }
        catch (error) {
            return [];
        }
    }
    async addRemote(name, url) {
        try {
            await execAsync(`git remote add ${name} ${url}`, { cwd: this.workspacePath });
        }
        catch (error) {
            throw new Error(`Failed to add remote: ${error}`);
        }
    }
    async isGitRepository() {
        try {
            await execAsync('git rev-parse --git-dir', { cwd: this.workspacePath });
            return true;
        }
        catch (error) {
            return false;
        }
    }
}
exports.GitService = GitService;
//# sourceMappingURL=gitService.js.map