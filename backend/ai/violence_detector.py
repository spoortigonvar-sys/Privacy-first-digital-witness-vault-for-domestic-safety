import os
import cv2
import torch
import torch.nn.functional as F
from pytorchvideo.models.hub.x3d import create_x3d


# ============================================================
# CONFIGURATION
# ============================================================

MODEL_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "models",
    "final",
    "final_x3d_realtime.pt",
)

NUM_FRAMES = 16
FRAME_SIZE = 224

# Model configuration says threshold = 0.4
VIOLENCE_THRESHOLD = 0.4


# ============================================================
# LOAD X3D MODEL
# ============================================================

def load_violence_model():

    print("Loading X3D-M model...")

    model = create_x3d(
        input_clip_length=16,
        input_crop_size=224,
        model_num_class=2,
        dropout_rate=0.3,
    )

    checkpoint = torch.load(
        MODEL_PATH,
        map_location="cpu",
        weights_only=False,
    )

    state_dict = checkpoint["model"]

    new_state_dict = {}

    for key, value in state_dict.items():

        new_key = key

        # Remove "backbone." prefix
        if new_key.startswith("backbone."):
            new_key = new_key[len("backbone."):]

        # Fix final classifier names
        if new_key == "blocks.5.proj.1.weight":
            new_key = "blocks.5.proj.weight"

        elif new_key == "blocks.5.proj.1.bias":
            new_key = "blocks.5.proj.bias"

        new_state_dict[new_key] = value

    model.load_state_dict(new_state_dict)

    model.eval()

    print("X3D-M model loaded successfully!")

    return model


# ============================================================
# EXTRACT VIDEO FRAMES
# ============================================================

def extract_frames(video_path):

    print("Reading video frames...")

    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        raise ValueError(
            f"Could not open video: {video_path}"
        )

    frames = []

    while True:

        success, frame = cap.read()

        if not success:
            break

        # Convert BGR to RGB
        frame = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        # Resize to X3D input size
        frame = cv2.resize(
            frame,
            (FRAME_SIZE, FRAME_SIZE)
        )

        # Convert image to tensor
        frame = torch.from_numpy(
            frame
        ).float() / 255.0

        # H,W,C -> C,H,W
        frame = frame.permute(
            2,
            0,
            1
        )

        frames.append(frame)

    cap.release()

    print(
        f"Total decoded frames: {len(frames)}"
    )

    if len(frames) == 0:

        raise ValueError(
            "No frames could be read from the video."
        )

    # ========================================================
    # SELECT EXACTLY 16 FRAMES
    # ========================================================

    if len(frames) < NUM_FRAMES:

        print(
            f"Video has fewer than {NUM_FRAMES} frames."
        )

        print(
            "Repeating the last frame."
        )

        while len(frames) < NUM_FRAMES:

            frames.append(
                frames[-1]
            )

    else:

        indices = torch.linspace(
            0,
            len(frames) - 1,
            NUM_FRAMES
        ).long().tolist()

        frames = [
            frames[index]
            for index in indices
        ]

    # ========================================================
    # T,C,H,W -> C,T,H,W
    # ========================================================

    video = torch.stack(frames)

    video = video.permute(
        1,
        0,
        2,
        3
    )

    # ========================================================
    # ADD BATCH DIMENSION
    #
    # C,T,H,W -> B,C,T,H,W
    # ========================================================

    video = video.unsqueeze(0)

    print(
        "Video tensor shape:",
        tuple(video.shape)
    )

    return video


# ============================================================
# VIOLENCE PREDICTION
# ============================================================

def predict_violence(model, video_path):

    print("Processing video...")

    print(
        "Video:",
        video_path
    )

    video = extract_frames(
        video_path
    )

    # ========================================================
    # MODEL INFERENCE
    # ========================================================

    with torch.no_grad():

        output = model(video)

        probabilities = F.softmax(
            output,
            dim=1
        )

    # ========================================================
    # GET CLASS PROBABILITIES
    #
    # CURRENT PROJECT ASSUMPTION:
    #
    # Class 0 = Non-violence
    # Class 1 = Violence
    # ========================================================

    class_0_probability = (
        probabilities[0][0].item()
    )

    class_1_probability = (
        probabilities[0][1].item()
    )

    # Class 1 is currently treated as violence
    violence_probability = (
        class_1_probability
    )

    # ========================================================
    # APPLY VIOLENCE THRESHOLD
    # ========================================================

    violence_detected = (
        violence_probability
        >= VIOLENCE_THRESHOLD
    )

    # ========================================================
    # DISPLAY RESULTS
    # ========================================================

    print()
    print("Raw model output:")
    print(output)

    print()
    print("Probabilities:")
    print(probabilities)

    print()
    print(
        f"Non-violence probability: "
        f"{class_0_probability:.4f}"
    )

    print(
        f"Violence probability: "
        f"{violence_probability:.4f}"
    )

    print(
        f"Violence threshold: "
        f"{VIOLENCE_THRESHOLD:.2f}"
    )

    print()

    if violence_detected:

        print(
            "!!! VIOLENCE DETECTED !!!"
        )

    else:

        print(
            "NO VIOLENCE DETECTED."
        )

    # ========================================================
    # RETURN RESULT
    # ========================================================

    return {
        "violence_detected": violence_detected,
        "violence_probability": violence_probability,
        "non_violence_probability": class_0_probability,
        "threshold": VIOLENCE_THRESHOLD,
    }


# ============================================================
# MAIN TEST
# ============================================================

if __name__ == "__main__":

    # Load model
    model = load_violence_model()

    # Test video
    video_path = os.path.join(
        os.path.dirname(
            os.path.dirname(__file__)
        ),
        "uploads",
        "REC2115049631340189785.mp4",
    )

    # Run prediction
    result = predict_violence(
        model,
        video_path
    )

    # ========================================================
    # FINAL RESULT
    # ========================================================

    print()
    print(
        "================================"
    )
    print(
        "       X3D TEST RESULT"
    )
    print(
        "================================"
    )

    print(
        f"Violence detected: "
        f"{result['violence_detected']}"
    )

    print(
        f"Violence probability: "
        f"{result['violence_probability']:.4f}"
    )

    print(
        f"Non-violence probability: "
        f"{result['non_violence_probability']:.4f}"
    )

    print(
        f"Threshold: "
        f"{result['threshold']:.2f}"
    )

    print(
        "================================"
    )