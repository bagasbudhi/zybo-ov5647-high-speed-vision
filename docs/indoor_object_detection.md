# Indoor object detection

## What it detects

The laptop-side detector uses the nano-sized YOLO11 model, starting from public COCO-pretrained weights and fine-tuning on HomeObjects-3K, a public indoor object-detection dataset. Its 12 labeled classes are bed, sofa, chair, table, lamp, TV, laptop, wardrobe, window, door, potted plant, and photo frame. The dataset has 2,285 training and 404 validation images. This is object detection: the output includes a class, confidence, and image-space bounding box for each finding. [Dataset description and license](https://docs.ultralytics.com/datasets/detect/homeobjects-3k)

It detects household objects within rooms; it does not classify the whole scene as “classroom” or “bedroom.” HomeObjects-3K does not label people, whiteboards, or projectors, and the fine-tuned model will not detect those. Detecting a human body or body parts requires a separate person/pose model and suitable labeled data.

## Camera and compute placement

```text
OV5647 -> CSI-2 -> Bayer8 -> DDR/VDMA -> HDMI
                                  |
                                  +-> captured Bayer8 frame -> laptop demosaic -> YOLO11n -> boxes + CSV
```

Neural inference runs on the laptop CPU by default. It is independent of the FPGA threshold detector and is not in the current bitstream. Ethernet frame transport is not implemented. For now, a Bayer8 frame can be acquired through the existing JTAG dump flow; an image/video/webcam source can also be passed directly to the detector. A later milestone can carry frames over Ethernet and report per-frame inference latency.

## Setup and inference

Use a separate Python environment if the existing Python setup is shared with other work. The Ultralytics runtime installs PyTorch, OpenCV, NumPy, and other dependencies; the first run downloads the public COCO-pretrained checkpoint. Then train the indoor model with the public HomeObjects-3K annotations.

```powershell
python -m pip install -r host/requirements-ml.txt

# Image, video, or webcam device 0
python host/indoor_detector.py detect path\to\classroom.jpg
python host/indoor_detector.py detect 0 --show

# One OV5647 Bayer8 frame dumped by fpga/dump_vga_frame_jtag.tcl
python host/indoor_detector.py detect build\capture\ov5647_live_640x480.raw --bayer8 --phase BG

# Use the fine-tuned HomeObjects-3K model after training
python host/indoor_detector.py detect path\to\bedroom.jpg --model runs/indoor/homeobjects3k_yolo11n_320/weights/best.pt
```

Annotated images are written under `build/indoor_detections/`, with one row per detection in `build/indoor_detections.csv`. The CSV records class, confidence, and pixel bounding box. Change `--model` to use a locally fine-tuned checkpoint. Bayer phase defaults to BG and should match the sensor capture mode.

## Fine-tuning on public data

The `HomeObjects-3K.yaml` configuration automatically downloads the public indoor dataset when training first runs (about 390 MB according to the dataset page). By default, the images and annotations are stored in this repository's ignored `build/datasets/` directory (override with `--dataset-dir`). The checkpoint starts from public COCO-pretrained YOLO11n weights, then fine-tunes on the 12 indoor categories. The command below uses a compact CPU-friendly run; increase epochs and image size if you have more compute. Use `--device 0` if a compatible CUDA GPU is available.

```powershell
python host/indoor_detector.py train --device cpu --epochs 5 --imgsz 320 --fraction 1.0 --dataset-dir build/datasets
```

The resulting model is under `runs/indoor/homeobjects3k_yolo11n/weights/best.pt` (the current 320px trial is named `homeobjects3k_yolo11n_320`). Training automatically evaluates against the dataset's held-out validation split and writes per-epoch metrics in `results.csv`. Review those metrics and several annotated validation examples before describing model quality. Do not report training-set accuracy as detector accuracy.

## Portfolio evidence and limitations

The detector is intended as a laptop-side AI extension to the Zybo camera-interface project. Its trained weights and model code do not imply neural inference on the XC7Z010 FPGA. The currently demonstrated FPGA path is Bayer-to-RGB, threshold/count/bounding-box logic, DDR/VDMA, and HDMI; the current board setup still needs a fresh live capture/ARM-DAP recovery before the entire camera-to-viewer loop can be demonstrated.

The project does not claim trained-model validation metrics until a full training run completes. A separate smoke inference using the public Ultralytics `bus.jpg` sample detected 4 people (confidence 0.62–0.89); CPU model inference was about 56 ms for that one image. The 1.87 s end-to-end time includes cold startup and model loading, so it is not a sustained video FPS measurement. This sample demonstrates the inference app only; it is not a classroom/bedroom result or a Zybo camera capture.

Record the `results.csv` validation metrics (especially mAP50-95, precision, and recall), the exact data fraction/epochs, and annotated held-out images before describing this as validated. Do not claim automotive qualification or safety performance. HomeObjects-3K and Ultralytics are marked AGPL-3.0; check the license terms before redistributing model weights or presenting it as part of a closed-source product. This repo intentionally does not check in the dataset or model weights.
