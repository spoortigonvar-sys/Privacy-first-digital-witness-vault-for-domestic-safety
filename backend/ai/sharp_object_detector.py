from pathlib import Path
import cv2
from ultralytics import YOLO


# ============================================================
# YOLO SHARP OBJECT DETECTOR
#
# Classes:
#   0 -> gun
#   1 -> knife
# ============================================================

BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = BASE_DIR / "models" / "best.pt"


# ============================================================
# DETECTION SETTINGS
# ============================================================

KNIFE_CONFIDENCE = 0.20

GUN_CONFIDENCE = 0.80

# Minimum number of frames in which an object
# must be detected before confirmation.
MIN_CONFIRMATION_FRAMES = 3

# Gun requires a higher percentage of processed
# frames to be consistent before confirmation.
GUN_MIN_FRAME_RATIO = 0.20


# ============================================================
# LOAD MODEL
# ============================================================

print("=" * 60)
print("YOLO SHARP OBJECT DETECTOR")
print("=" * 60)

print("Loading YOLO model from:")
print(MODEL_PATH)


if not MODEL_PATH.exists():
    raise FileNotFoundError(
        f"YOLO model not found at: {MODEL_PATH}"
    )


model = YOLO(str(MODEL_PATH))


print("\nYOLO model loaded successfully!")

print("\nDetected model classes:")

for class_id, class_name in model.names.items():
    print(f"{class_id} -> {class_name}")


print("\nYOLO detector is ready.")
print("=" * 60)


# ============================================================
# IMAGE DETECTION
# ============================================================

def detect_sharp_objects(
    image_path,
    confidence=0.20
):
    """
    Detect gun and knife in a single image.
    """

    results = model.predict(
        source=image_path,
        conf=confidence,
        verbose=False
    )

    detected_objects = []

    for result in results:

        if result.boxes is None:
            continue

        for box in result.boxes:

            class_id = int(box.cls[0])

            confidence_score = float(
                box.conf[0]
            )

            class_name = model.names[class_id]

            detected_objects.append({
                "class_id": class_id,
                "class_name": class_name,
                "confidence": round(
                    confidence_score,
                    4
                )
            })

    return {
        "detected": len(detected_objects) > 0,
        "objects": detected_objects
    }


# ============================================================
# VIDEO DETECTION
# ============================================================

def detect_sharp_objects_in_video(
    video_path,
    frame_skip=1
):
    """
    Detect knives and guns in a video.

    Knife:
        confidence >= 0.20

    Gun:
        confidence >= 0.40

    Confirmation:
        Knife requires at least 3 frames.

        Gun requires at least 3 frames AND
        must appear in at least 20% of the
        processed frames.
    """

    print("\n" + "=" * 60)
    print("YOLO VIDEO DETECTION")
    print("=" * 60)

    print(f"Video: {video_path}")

    print(
        f"Knife confidence threshold: "
        f"{KNIFE_CONFIDENCE}"
    )

    print(
        f"Gun confidence threshold: "
        f"{GUN_CONFIDENCE}"
    )

    print(
        f"Minimum confirmation frames: "
        f"{MIN_CONFIRMATION_FRAMES}"
    )

    print(
        f"Gun minimum frame ratio: "
        f"{GUN_MIN_FRAME_RATIO}"
    )

    print(
        f"Processing every {frame_skip} frame(s)"
    )


    # --------------------------------------------------------
    # CHECK VIDEO
    # --------------------------------------------------------

    if not Path(video_path).exists():

        raise FileNotFoundError(
            f"Video not found: {video_path}"
        )


    video = cv2.VideoCapture(
        str(video_path)
    )


    if not video.isOpened():

        raise RuntimeError(
            f"Could not open video: {video_path}"
        )


    total_frames = int(
        video.get(cv2.CAP_PROP_FRAME_COUNT)
    )

    fps = video.get(
        cv2.CAP_PROP_FPS
    )


    print(
        f"Total frames: {total_frames}"
    )

    print(
        f"FPS: {fps:.2f}"
    )


    # --------------------------------------------------------
    # FALSE GUN DETECTION FRAMES
    # --------------------------------------------------------

    false_gun_dir = (
        BASE_DIR / "false_gun_detections"
    )

    false_gun_dir.mkdir(
        exist_ok=True
    )


    # --------------------------------------------------------
    # TRACK DETECTIONS
    # --------------------------------------------------------

    knife_frame_count = 0
    gun_frame_count = 0

    processed_frame_count = 0

    highest_knife_confidence = 0.0
    highest_gun_confidence = 0.0

    knife_frames = []
    gun_frames = []

    all_detections = []

    frame_number = 0


    # --------------------------------------------------------
    # PROCESS VIDEO
    # --------------------------------------------------------

    while True:

        success, frame = video.read()

        if not success:
            break

        frame_number += 1


        # Process selected frames only
        if frame_number % frame_skip != 0:
            continue


        processed_frame_count += 1


        results = model.predict(
            source=frame,
            conf=0.01,
            verbose=False
        )


        frame_has_knife = False
        frame_has_gun = False


        for result in results:

            if result.boxes is None:
                continue


            for box in result.boxes:

                class_id = int(
                    box.cls[0]
                )

                confidence_score = float(
                    box.conf[0]
                )

                class_name = (
                    model.names[class_id]
                ).lower()


                # ------------------------------------------------
                # KNIFE
                # ------------------------------------------------

                if (
                    class_name == "knife"
                    and
                    confidence_score >= KNIFE_CONFIDENCE
                ):

                    frame_has_knife = True


                    if (
                        confidence_score
                        > highest_knife_confidence
                    ):

                        highest_knife_confidence = (
                            confidence_score
                        )


                    all_detections.append({
                        "frame": frame_number,
                        "class_id": class_id,
                        "class_name": "knife",
                        "confidence": round(
                            confidence_score,
                            4
                        )
                    })


                # ------------------------------------------------
                # GUN
                # ------------------------------------------------

                elif (
                    class_name == "gun"
                    and
                    confidence_score >= GUN_CONFIDENCE
                ):

                    frame_has_gun = True


                    if (
                        confidence_score
                        > highest_gun_confidence
                    ):

                        highest_gun_confidence = (
                            confidence_score
                        )


                    all_detections.append({
                        "frame": frame_number,
                        "class_id": class_id,
                        "class_name": "gun",
                        "confidence": round(
                            confidence_score,
                            4
                        )
                    })


                    # --------------------------------------------
                    # SAVE DIAGNOSTIC FRAME
                    # --------------------------------------------

                    output_path = (
                        false_gun_dir
                        / (
                            f"gun_frame_"
                            f"{frame_number}_"
                            f"conf_"
                            f"{confidence_score:.3f}.jpg"
                        )
                    )

                    cv2.imwrite(
                        str(output_path),
                        frame
                    )


        # --------------------------------------------------------
        # COUNT FRAME DETECTIONS
        # --------------------------------------------------------

        if frame_has_knife:

            knife_frame_count += 1

            knife_frames.append(
                frame_number
            )


        if frame_has_gun:

            gun_frame_count += 1

            gun_frames.append(
                frame_number
            )


    video.release()


    # ============================================================
    # CALCULATE FRAME RATIOS
    # ============================================================

    knife_frame_ratio = 0.0
    gun_frame_ratio = 0.0


    if processed_frame_count > 0:

        knife_frame_ratio = (
            knife_frame_count
            / processed_frame_count
        )

        gun_frame_ratio = (
            gun_frame_count
            / processed_frame_count
        )


    # ============================================================
    # FINAL CONFIRMATION
    # ============================================================

    knife_confirmed = (
        knife_frame_count
        >= MIN_CONFIRMATION_FRAMES
    )


    gun_confirmed = (
        gun_frame_count
        >= MIN_CONFIRMATION_FRAMES
        and
        gun_frame_ratio
        >= GUN_MIN_FRAME_RATIO
    )


    sharp_object_detected = (
        knife_confirmed
        or
        gun_confirmed
    )


    # ============================================================
    # PRINT RESULT
    # ============================================================

    print("\n" + "=" * 60)
    print("VIDEO PROCESSING COMPLETED")
    print("=" * 60)


    print("\nDetection summary:")


    print(
        f"Processed frames: "
        f"{processed_frame_count}"
    )


    print(
        f"\nKnife confirmation frames: "
        f"{knife_frame_count}"
    )


    print(
        f"Knife frame ratio: "
        f"{knife_frame_ratio:.2%}"
    )


    print(
        f"Knife detected: "
        f"{knife_confirmed}"
    )


    print(
        f"Highest knife confidence: "
        f"{highest_knife_confidence:.4f}"
    )


    print(
        f"\nGun confirmation frames: "
        f"{gun_frame_count}"
    )


    print(
        f"Gun frame ratio: "
        f"{gun_frame_ratio:.2%}"
    )


    print(
        f"Gun detected: "
        f"{gun_confirmed}"
    )


    print(
        f"Highest gun confidence: "
        f"{highest_gun_confidence:.4f}"
    )


    print(
        f"\nTotal confirmed sharp-object "
        f"detections: "
        f"{len(all_detections)}"
    )


    print(
        f"\nDiagnostic gun frames saved to:"
        f"\n{false_gun_dir}"
    )


    # ============================================================
    # RETURN RESULT
    # ============================================================

    return {

        "sharp_object_detected":
            sharp_object_detected,

        "knife_detected":
            knife_confirmed,

        "gun_detected":
            gun_confirmed,

        "knife_confirmation_frames":
            knife_frame_count,

        "gun_confirmation_frames":
            gun_frame_count,

        "knife_frame_ratio":
            round(
                knife_frame_ratio,
                4
            ),

        "gun_frame_ratio":
            round(
                gun_frame_ratio,
                4
            ),

        "highest_knife_confidence":
            round(
                highest_knife_confidence,
                4
            ),

        "highest_gun_confidence":
            round(
                highest_gun_confidence,
                4
            ),

        "knife_frames":
            knife_frames,

        "gun_frames":
            gun_frames,

        "detections":
            all_detections
    }