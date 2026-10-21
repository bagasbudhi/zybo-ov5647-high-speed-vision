# Indoor object detection

## What it detects

The laptop-side detector uses YOLO11n, initialized from public COCO-pretrained weights and fine-tuned on HomeObjects-3K. Its 12 object classes are bed, sofa, chair, table, lamp, TV, laptop, wardrobe, window, door, potted plant, and photo frame. The dataset contains 2,285 training and 404 validation images. Each finding includes a class, confidence, and image-space bounding box. [Dataset description and license](https://docs.ultralytics.com/datasets/detect/homeobjects-3k)

This detects objects within a room; it does not classify a whole scene as a classroom or bedroom. HomeObjects-3K has no labels for people, whiteboards, or projectors. Detecting people or body pose requires a model trained for those labels. The original COCO checkpoint can detect people, but person boxes do not provide body-part or pose recognition.

## Camera and compute placement

```text
OV5647 -> CSI-2 -> Bayer8 -> DDR/VDMA -> HDMI
                                  |
                                  +-> captured Bayer8 frame -> laptop demosaic -> YOLO11n -> boxes + CSV
```

Neural inference runs on the laptop CPU by default. It is separate from the FPGA threshold detector and is not in the current bitstream. Ethernet frame transport is not implemented. A Bayer8 frame can currently be acquired through the JTAG dump flow; an image, video, or webcam can also be passed directly to the detector.

## Setup and inference

```powershell
python -m pip install -r host/requirements-ml.txt

# Image, video, or webcam device 0 with the COCO checkpoint
python host/indoor_detector.py detect path\to\classroom.jpg
python host/indoor_detector.py detect 0 --show

# Bayer8 frame dump from fpga/dump_vga_frame_jtag.tcl
python host/indoor_detector.py detect build\capture\ov5647_live_640x480.raw --bayer8 --phase BG

# Fine-tuned HomeObjects-3K model
python host/indoor_detector.py detect path\to\bedroom.jpg --model runs/indoor/homeobjects3k_yolo11n_320/weights/best.pt
```

Annotated images go under `build/indoor_detections/`; `build/indoor_detections.csv` records class, confidence, and pixel bounding box. Bayer phase defaults to BG and must match the sensor capture mode.

## Fine-tuning on public data

The `HomeObjects-3K.yaml` configuration downloads the public dataset on the first run (about 390 MB). Images and labels are stored in the ignored `build/datasets/` folder by default. Model checkpoints are not committed.

The completed trial used the full training split, 5 epochs, 320px images, deterministic seed 7, and CPU training on a Ryzen 7 7735HS laptop:

```powershell
python host/indoor_detector.py train --model yolo11n.pt --device cpu --epochs 5 --imgsz 320 --fraction 1.0 --dataset-dir build/datasets --name homeobjects3k_yolo11n_320
```

The best checkpoint scored precision 0.545, recall 0.505, mAP@0.5 0.520, and mAP@0.5:0.95 0.342 on 404 held-out validation images containing 3,470 labeled objects. Per-epoch results are in `runs/indoor/homeobjects3k_yolo11n_320/results.csv`. These are short-run benchmark results, not production accuracy.

## Portfolio evidence and limitations

A held-out HomeObjects image (`living_room_10.jpg`) produced 4 detections: 2 potted plants, 1 sofa, and 1 table. Model inference took about 29 ms for that image. An earlier local OV5647 Bayer8 capture was processed offline and produced one photo-frame detection, also at about 29 ms model inference. That camera capture has no object annotations, so this is a functional smoke check, not an accuracy measurement or fresh live camera-to-viewer demonstration. A separate public Ultralytics `bus.jpg` smoke inference using the COCO checkpoint detected 4 people (confidence 0.62–0.89); CPU inference was about 56 ms. Cold end-to-end timings include model startup and do not represent sustained video FPS.

This project demonstrates laptop-side AI alongside FPGA camera-interface and threshold/count/bounding-box RTL. It does not demonstrate neural inference on the XC7Z010 or Ethernet streaming. The camera-to-TV live path still needs a fresh end-to-end demonstration. Do not claim automotive qualification or safety performance. HomeObjects-3K and Ultralytics are marked AGPL-3.0; review their license terms before redistributing model weights or using the work in a closed-source product. The repository does not include the downloaded data or model weights.
