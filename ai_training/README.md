# 🤖 Reminda AI - Custom Schedule Training Pipeline

Welcome to the proprietary AI training pipeline for **Reminda**. This pipeline allows you to create high-accuracy synthetic Philippine schedule datasets, fine-tune lightweight Vision-Document models (Donut / TrOCR / LayoutLM), and quantize them to `.tflite` for 100% offline on-device scanning.

---

## 📁 Pipeline Architecture

```
ai_training/
├── dataset/
│   ├── images/               # Synthetic & collected schedule images (.jpg)
│   └── labels/               # Ground-truth ScheduleEntry JSON files (.json)
├── generate_schedule_dataset.py # High-speed Philippine synthetic schedule generator
├── train_donut.py            # PyTorch + HuggingFace Donut fine-tuning script
└── export_model.py           # Quantization & mobile export to .onnx / .pt
```

---

## 🚀 Quickstart Guide

### 1. Install Requirements
```bash
pip install torch torchvision transformers pillow albumentations datasets
```

### 2. Generate Synthetic Dataset (e.g. 1,000 samples)
```bash
python ai_training/generate_schedule_dataset.py
```

### 3. Fine-Tune Document Model
```bash
python ai_training/train_donut.py --epochs 10 --batch_size 4
```

### 4. Export for Flutter Android / iOS / Desktop
```bash
python ai_training/export_model.py --model_dir ./output_model
```
The exported `encoder_model.onnx` and model config can then be placed directly into `assets/models/` in the Reminda Flutter app for instant, zero-internet offline scanning!
