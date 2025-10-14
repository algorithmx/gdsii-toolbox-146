import './style.css'

interface GDSPoint {
  x: number;
  y: number;
}

interface GDSLayer {
  number: number;
  dataType: number;
  name?: string;
  color: string;
  visible: boolean;
}

interface GDSStructure {
  name: string;
  elements: GDSElement[];
  references: GDSReference[];
}

interface GDSElement {
  type: 'boundary' | 'path' | 'text' | 'box' | 'node';
  layer: number;
  dataType: number;
  points: GDSPoint[];
  properties?: Record<string, any>;
}

interface GDSReference {
  type: 'sref' | 'aref';
  name: string;
  position: GDSPoint;
  rotation?: number;
  magnification?: number;
  columns?: number;
  rows?: number;
  spacing?: GDSPoint;
}

interface GDSLibrary {
  name: string;
  units: {
    userUnitsPerDatabaseUnit: number;
    metersPerDatabaseUnit: number;
  };
  structures: GDSStructure[];
}

class GDSViewer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private fileInput: HTMLInputElement;
  private loadButton: HTMLButtonElement;
  private fileInfo: HTMLParagraphElement;
  private layerList: HTMLDivElement;
  private zoomInButton: HTMLButtonElement;
  private zoomOutButton: HTMLButtonElement;
  private resetViewButton: HTMLButtonElement;
  private infoPanel: HTMLDivElement;

  private currentLibrary: GDSLibrary | null = null;
  private scale: number = 1;
  private offsetX: number = 0;
  private offsetY: number = 0;
  private isDragging: boolean = false;
  private dragStart: GDSPoint = { x: 0, y: 0 };
  private lastOffset: GDSPoint = { x: 0, y: 0 };

  constructor() {
    this.canvas = document.getElementById('gdsCanvas') as HTMLCanvasElement;
    this.ctx = this.canvas.getContext('2d')!;
    this.fileInput = document.getElementById('fileInput') as HTMLInputElement;
    this.loadButton = document.getElementById('loadButton') as HTMLButtonElement;
    this.fileInfo = document.getElementById('fileInfo') as HTMLParagraphElement;
    this.layerList = document.getElementById('layerList') as HTMLDivElement;
    this.zoomInButton = document.getElementById('zoomIn') as HTMLButtonElement;
    this.zoomOutButton = document.getElementById('zoomOut') as HTMLButtonElement;
    this.resetViewButton = document.getElementById('resetView') as HTMLButtonElement;
    this.infoPanel = document.getElementById('infoPanel') as HTMLDivElement;

    this.setupEventListeners();
    this.resizeCanvas();
    this.drawPlaceholder();
  }

  private setupEventListeners() {
    this.loadButton.addEventListener('click', () => this.loadFile());
    this.fileInput.addEventListener('change', () => this.processFile());

    this.zoomInButton.addEventListener('click', () => this.zoom(1.2));
    this.zoomOutButton.addEventListener('click', () => this.zoom(0.8));
    this.resetViewButton.addEventListener('click', () => this.resetView());

    this.canvas.addEventListener('mousedown', (e) => this.handleMouseDown(e));
    this.canvas.addEventListener('mousemove', (e) => this.handleMouseMove(e));
    this.canvas.addEventListener('mouseup', () => this.handleMouseUp());
    this.canvas.addEventListener('wheel', (e) => this.handleWheel(e));

    window.addEventListener('resize', () => this.resizeCanvas());
  }

  private async loadFile() {
    this.fileInput.click();
  }

  private async processFile() {
    const file = this.fileInput.files?.[0];
    if (!file) {
      this.showMessage('Please select a GDSII file');
      return;
    }

    if (!file.name.match(/\.(gds|gdsii|gds2)$/i)) {
      this.showMessage('Please select a valid GDSII file (.gds, .gdsii, .gds2)');
      return;
    }

    this.showMessage(`Loading ${file.name}...`);

    try {
      const arrayBuffer = await file.arrayBuffer();
      const data = new Uint8Array(arrayBuffer);

      this.currentLibrary = await this.parseGDSII(data);
      this.updateFileInfo(file.name);
      this.updateLayerList();
      this.resetView();

    } catch (error) {
      console.error('Error loading GDSII file:', error);
      this.showMessage(`Error loading file: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private async parseGDSII(data: Uint8Array): Promise<GDSLibrary> {
    console.log('GDSII parsing placeholder - received', data.length, 'bytes');

    await new Promise(resolve => setTimeout(resolve, 500));

    return {
      name: 'Demo Library',
      units: {
        userUnitsPerDatabaseUnit: 0.001,
        metersPerDatabaseUnit: 1e-9
      },
      structures: [
        {
          name: 'TOP_CELL',
          elements: [
            {
              type: 'boundary',
              layer: 1,
              dataType: 0,
              points: [
                { x: -100, y: -100 },
                { x: 100, y: -100 },
                { x: 100, y: 100 },
                { x: -100, y: 100 }
              ]
            },
            {
              type: 'boundary',
              layer: 2,
              dataType: 0,
              points: [
                { x: -50, y: -50 },
                { x: 50, y: -50 },
                { x: 50, y: 50 },
                { x: -50, y: 50 }
              ]
            },
            {
              type: 'path',
              layer: 3,
              dataType: 0,
              points: [
                { x: -150, y: 0 },
                { x: 150, y: 0 }
              ]
            }
          ],
          references: []
        }
      ]
    };
  }

  private updateFileInfo(fileName: string) {
    if (!this.currentLibrary) return;

    const totalElements = this.currentLibrary.structures
      .reduce((sum, struct) => sum + struct.elements.length, 0);

    this.fileInfo.innerHTML = `
      <strong>File:</strong> ${fileName}<br>
      <strong>Library:</strong> ${this.currentLibrary.name}<br>
      <strong>Structures:</strong> ${this.currentLibrary.structures.length}<br>
      <strong>Total Elements:</strong> ${totalElements}
    `;
  }

  private updateLayerList() {
    if (!this.currentLibrary) return;

    const layers = new Map<number, GDSLayer>();

    this.currentLibrary.structures.forEach(struct => {
      struct.elements.forEach(element => {
        if (!layers.has(element.layer)) {
          layers.set(element.layer, {
            number: element.layer,
            dataType: element.dataType,
            color: this.getLayerColor(element.layer),
            visible: true
          });
        }
      });
    });

    this.layerList.innerHTML = '';
    layers.forEach((layer, number) => {
      const layerItem = document.createElement('div');
      layerItem.className = 'layer-item';
      layerItem.innerHTML = `
        <div class="layer-color" style="background-color: ${layer.color}"></div>
        <input type="checkbox" id="layer-${number}" checked>
        <label for="layer-${number}">Layer ${number} (DT ${layer.dataType})</label>
      `;

      const checkbox = layerItem.querySelector(`#layer-${number}`) as HTMLInputElement;
      checkbox.addEventListener('change', () => {
        layer.visible = checkbox.checked;
        this.render();
      });

      this.layerList.appendChild(layerItem);
    });
  }

  private getLayerColor(layerNumber: number): string {
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    return colors[layerNumber % colors.length];
  }

  private resizeCanvas() {
    const wrapper = this.canvas.parentElement as HTMLElement;
    if (wrapper) {
      this.canvas.width = wrapper.clientWidth;
      this.canvas.height = wrapper.clientHeight;
      this.render();
    }
  }

  
  private drawPlaceholder() {
    this.ctx.fillStyle = '#f0f0f0';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    this.ctx.fillStyle = '#999';
    this.ctx.font = '16px system-ui';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillText('Load a GDSII file to visualize', this.canvas.width / 2, this.canvas.height / 2);
  }

  private render() {
    if (!this.currentLibrary) {
      this.drawPlaceholder();
      return;
    }

    this.ctx.fillStyle = '#ffffff';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    this.ctx.save();
    this.ctx.translate(this.canvas.width / 2 + this.offsetX, this.canvas.height / 2 + this.offsetY);
    this.ctx.scale(this.scale, -this.scale);

    this.currentLibrary.structures.forEach(structure => {
      structure.elements.forEach(element => {
        this.drawElement(element);
      });
    });

    this.ctx.restore();
  }

  private drawElement(element: GDSElement) {
    const color = this.getLayerColor(element.layer);
    this.ctx.strokeStyle = color;
    this.ctx.fillStyle = color;
    this.ctx.lineWidth = 1 / this.scale;

    switch (element.type) {
      case 'boundary':
        if (element.points.length >= 3) {
          this.ctx.beginPath();
          this.ctx.moveTo(element.points[0].x, element.points[0].y);
          for (let i = 1; i < element.points.length; i++) {
            this.ctx.lineTo(element.points[i].x, element.points[i].y);
          }
          this.ctx.closePath();
          this.ctx.globalAlpha = 0.3;
          this.ctx.fill();
          this.ctx.globalAlpha = 1.0;
          this.ctx.stroke();
        }
        break;

      case 'path':
        if (element.points.length >= 2) {
          this.ctx.beginPath();
          this.ctx.moveTo(element.points[0].x, element.points[0].y);
          for (let i = 1; i < element.points.length; i++) {
            this.ctx.lineTo(element.points[i].x, element.points[i].y);
          }
          this.ctx.stroke();
        }
        break;

      case 'text':
        if (element.points.length > 0) {
          this.ctx.save();
          this.ctx.scale(1 / this.scale, -1 / this.scale);
          this.ctx.font = `${12 / this.scale}px system-ui`;
          this.ctx.fillText('TEXT', element.points[0].x, -element.points[0].y);
          this.ctx.restore();
        }
        break;
    }
  }

  private zoom(factor: number) {
    this.scale *= factor;
    this.scale = Math.max(0.01, Math.min(100, this.scale));
    this.render();
  }

  private resetView() {
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.render();
  }

  private handleMouseDown(e: MouseEvent) {
    this.isDragging = true;
    this.dragStart = { x: e.clientX, y: e.clientY };
    this.lastOffset = { x: this.offsetX, y: this.offsetY };
    this.canvas.style.cursor = 'grabbing';
  }

  private handleMouseMove(e: MouseEvent) {
    if (!this.isDragging) return;

    const dx = e.clientX - this.dragStart.x;
    const dy = e.clientY - this.dragStart.y;

    this.offsetX = this.lastOffset.x + dx;
    this.offsetY = this.lastOffset.y + dy;

    this.render();
  }

  private handleMouseUp() {
    this.isDragging = false;
    this.canvas.style.cursor = 'grab';
  }

  private handleWheel(e: WheelEvent) {
    e.preventDefault();
    const factor = e.deltaY > 0 ? 0.9 : 1.1;
    this.zoom(factor);
  }

  private showMessage(message: string) {
    this.fileInfo.textContent = message;
  }
}

const viewer = new GDSViewer();