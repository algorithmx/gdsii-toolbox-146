/**
 * Debug Logger Module
 * 
 * Comprehensive logging system for tracking renderer operations
 * and performance metrics in real-time.
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

export enum LogCategory {
  RENDERER = 'RENDERER',
  SCENE_GRAPH = 'SCENE',
  SPATIAL_INDEX = 'SPATIAL',
  VIEWPORT = 'VIEWPORT',
  CULLING = 'CULLING',
  DRAWING = 'DRAWING',
  PERFORMANCE = 'PERF',
  LAYER = 'LAYER',
  SYSTEM = 'SYSTEM'
}

interface LogEntry {
  timestamp: number;
  level: LogLevel;
  category: LogCategory;
  message: string;
  data?: any;
}

interface LogStats {
  totalLogs: number;
  byLevel: Map<LogLevel, number>;
  byCategory: Map<LogCategory, number>;
  startTime: number;
}

export class DebugLogger {
  private logs: LogEntry[] = [];
  private maxLogs: number = 1000;
  private enabled: boolean = true;
  private minLevel: LogLevel = LogLevel.DEBUG;
  private stats: LogStats;
  private listeners: ((entry: LogEntry) => void)[] = [];
  
  // UI Elements
  private logContainer: HTMLDivElement | null = null;
  private logList: HTMLDivElement | null = null;
  private statsPanel: HTMLDivElement | null = null;
  private filterButtons: Map<LogCategory, HTMLButtonElement> = new Map();
  private activeFilters: Set<LogCategory> = new Set();
  
  constructor() {
    this.stats = {
      totalLogs: 0,
      byLevel: new Map(),
      byCategory: new Map(),
      startTime: performance.now()
    };
    
    // Initialize all categories as active
    Object.values(LogCategory).forEach(cat => this.activeFilters.add(cat as LogCategory));
  }
  
  /**
   * Initialize the visual logger UI
   */
  public initializeUI(): void {
    // Create logger container
    this.logContainer = document.createElement('div');
    this.logContainer.id = 'debug-logger';
    this.logContainer.style.cssText = `
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 300px;
      background: rgba(0, 0, 0, 0.95);
      color: #00ff00;
      font-family: 'Courier New', monospace;
      font-size: 11px;
      z-index: 10000;
      display: flex;
      flex-direction: column;
      border-top: 2px solid #00ff00;
    `;
    
    // Create header with controls
    const header = document.createElement('div');
    header.style.cssText = `
      padding: 8px;
      background: #1a1a1a;
      border-bottom: 1px solid #00ff00;
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    `;
    
    // Title
    const title = document.createElement('span');
    title.textContent = '🔬 Debug Logger';
    title.style.cssText = 'font-weight: bold; margin-right: 16px;';
    header.appendChild(title);
    
    // Category filters
    Object.values(LogCategory).forEach(category => {
      const btn = document.createElement('button');
      btn.textContent = category;
      btn.style.cssText = `
        padding: 2px 8px;
        background: #00ff00;
        color: #000;
        border: none;
        cursor: pointer;
        font-size: 10px;
        font-weight: bold;
      `;
      btn.onclick = () => this.toggleFilter(category as LogCategory, btn);
      this.filterButtons.set(category as LogCategory, btn);
      header.appendChild(btn);
    });
    
    // Clear button
    const clearBtn = document.createElement('button');
    clearBtn.textContent = '🗑️ Clear';
    clearBtn.style.cssText = `
      padding: 2px 8px;
      background: #ff0000;
      color: #fff;
      border: none;
      cursor: pointer;
      font-size: 10px;
      margin-left: auto;
    `;
    clearBtn.onclick = () => this.clear();
    header.appendChild(clearBtn);
    
    // Close button
    const closeBtn = document.createElement('button');
    closeBtn.textContent = '✕';
    closeBtn.style.cssText = `
      padding: 2px 8px;
      background: #666;
      color: #fff;
      border: none;
      cursor: pointer;
      font-size: 10px;
    `;
    closeBtn.onclick = () => this.hide();
    header.appendChild(closeBtn);
    
    this.logContainer.appendChild(header);
    
    // Stats panel
    this.statsPanel = document.createElement('div');
    this.statsPanel.style.cssText = `
      padding: 4px 8px;
      background: #0a0a0a;
      border-bottom: 1px solid #333;
      font-size: 10px;
      color: #888;
    `;
    this.logContainer.appendChild(this.statsPanel);
    
    // Log list
    this.logList = document.createElement('div');
    this.logList.style.cssText = `
      flex: 1;
      overflow-y: auto;
      padding: 8px;
    `;
    this.logContainer.appendChild(this.logList);
    
    document.body.appendChild(this.logContainer);
    
    // Update stats periodically
    setInterval(() => this.updateStatsDisplay(), 1000);
  }
  
  /**
   * Toggle category filter
   */
  private toggleFilter(category: LogCategory, button: HTMLButtonElement): void {
    if (this.activeFilters.has(category)) {
      this.activeFilters.delete(category);
      button.style.background = '#666';
      button.style.color = '#fff';
    } else {
      this.activeFilters.add(category);
      button.style.background = '#00ff00';
      button.style.color = '#000';
    }
    this.refreshDisplay();
  }
  
  /**
   * Show logger
   */
  public show(): void {
    if (this.logContainer) {
      this.logContainer.style.display = 'flex';
    }
  }
  
  /**
   * Hide logger
   */
  public hide(): void {
    if (this.logContainer) {
      this.logContainer.style.display = 'none';
    }
  }
  
  /**
   * Log a message
   */
  public log(level: LogLevel, category: LogCategory, message: string, data?: any): void {
    if (!this.enabled || level < this.minLevel) return;
    
    const entry: LogEntry = {
      timestamp: performance.now(),
      level,
      category,
      message,
      data
    };
    
    this.logs.push(entry);
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
    
    // Update stats
    this.stats.totalLogs++;
    this.stats.byLevel.set(level, (this.stats.byLevel.get(level) || 0) + 1);
    this.stats.byCategory.set(category, (this.stats.byCategory.get(category) || 0) + 1);
    
    // Notify listeners
    this.listeners.forEach(listener => listener(entry));
    
    // Update UI if visible
    if (this.logList && this.activeFilters.has(category)) {
      this.appendLogToUI(entry);
    }
  }
  
  /**
   * Convenience methods
   */
  public debug(category: LogCategory, message: string, data?: any): void {
    this.log(LogLevel.DEBUG, category, message, data);
  }
  
  public info(category: LogCategory, message: string, data?: any): void {
    this.log(LogLevel.INFO, category, message, data);
  }
  
  public warn(category: LogCategory, message: string, data?: any): void {
    this.log(LogLevel.WARN, category, message, data);
  }
  
  public error(category: LogCategory, message: string, data?: any): void {
    this.log(LogLevel.ERROR, category, message, data);
  }
  
  /**
   * Append log entry to UI
   */
  private appendLogToUI(entry: LogEntry): void {
    if (!this.logList) return;
    
    const logDiv = document.createElement('div');
    logDiv.style.cssText = `
      padding: 2px 0;
      border-bottom: 1px solid #222;
      white-space: pre-wrap;
      word-wrap: break-word;
    `;
    
    // Color by level
    let color = '#00ff00';
    switch (entry.level) {
      case LogLevel.DEBUG: color = '#888'; break;
      case LogLevel.INFO: color = '#00ff00'; break;
      case LogLevel.WARN: color = '#ffaa00'; break;
      case LogLevel.ERROR: color = '#ff0000'; break;
    }
    
    const time = ((entry.timestamp - this.stats.startTime) / 1000).toFixed(3);
    const levelStr = LogLevel[entry.level].padEnd(5);
    const categoryStr = entry.category.padEnd(8);
    
    logDiv.innerHTML = `
      <span style="color: #666">[${time}s]</span>
      <span style="color: ${color}">[${levelStr}]</span>
      <span style="color: #00aaff">[${categoryStr}]</span>
      <span style="color: ${color}">${this.escapeHtml(entry.message)}</span>
      ${entry.data ? `<span style="color: #888"> ${this.escapeHtml(JSON.stringify(entry.data))}</span>` : ''}
    `;
    
    this.logList.appendChild(logDiv);
    
    // Auto-scroll to bottom
    this.logList.scrollTop = this.logList.scrollHeight;
    
    // Limit DOM nodes
    while (this.logList.children.length > 200) {
      this.logList.removeChild(this.logList.firstChild!);
    }
  }
  
  /**
   * Refresh entire display
   */
  private refreshDisplay(): void {
    if (!this.logList) return;
    
    this.logList.innerHTML = '';
    this.logs
      .filter(entry => this.activeFilters.has(entry.category))
      .slice(-200) // Last 200 logs
      .forEach(entry => this.appendLogToUI(entry));
  }
  
  /**
   * Update stats display
   */
  private updateStatsDisplay(): void {
    if (!this.statsPanel) return;
    
    const elapsed = ((performance.now() - this.stats.startTime) / 1000).toFixed(1);
    const rate = (this.stats.totalLogs / parseFloat(elapsed)).toFixed(1);
    
    let statsHtml = `📊 Total: ${this.stats.totalLogs} logs | Rate: ${rate} logs/s | Runtime: ${elapsed}s`;
    
    // Add level breakdown
    statsHtml += ' | Levels: ';
    [LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR].forEach(level => {
      const count = this.stats.byLevel.get(level) || 0;
      if (count > 0) {
        statsHtml += `${LogLevel[level]}:${count} `;
      }
    });
    
    this.statsPanel.innerHTML = statsHtml;
  }
  
  /**
   * Clear logs
   */
  public clear(): void {
    this.logs = [];
    this.stats = {
      totalLogs: 0,
      byLevel: new Map(),
      byCategory: new Map(),
      startTime: performance.now()
    };
    if (this.logList) {
      this.logList.innerHTML = '';
    }
  }
  
  /**
   * Add listener
   */
  public addListener(listener: (entry: LogEntry) => void): void {
    this.listeners.push(listener);
  }
  
  /**
   * Get logs
   */
  public getLogs(): LogEntry[] {
    return [...this.logs];
  }
  
  /**
   * Get stats
   */
  public getStats(): LogStats {
    return { ...this.stats };
  }
  
  /**
   * Enable/disable logging
   */
  public setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }
  
  /**
   * Set minimum log level
   */
  public setMinLevel(level: LogLevel): void {
    this.minLevel = level;
  }
  
  /**
   * Escape HTML
   */
  private escapeHtml(text: string): string {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
  
  /**
   * Export logs
   */
  public exportLogs(): string {
    return JSON.stringify(this.logs, null, 2);
  }
  
  /**
   * Download logs as file
   */
  public downloadLogs(): void {
    const data = this.exportLogs();
    const blob = new Blob([data], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `debug-logs-${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }
}

// Global logger instance
export const logger = new DebugLogger();

// Make it available globally for debugging
(window as any).debugLogger = logger;
