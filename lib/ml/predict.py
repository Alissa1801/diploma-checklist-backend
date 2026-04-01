import sys
import os
import json
import warnings
import shutil

# --- ОСТАВЛЯЕМ ТОЛЬКО ИМПОРТЫ И ФИКС ТИПОВ ---
try:
    import numpy as np
    # Этот фикс важен, если прилетит NumPy версии 2.0+
    np.ndarray = type(np.array([]))
    from ultralytics import YOLO
except ImportError as e:
    # Оставляем отладочный вывод, на всякий случай
    print(json.dumps({"error": f"Import failed: {str(e)}", "sys_path": sys.path}))
    sys.exit(1)

# Настройка вывода UTF-8
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

def run_prediction(image_path, model_path):
    if not os.path.exists(image_path):
        print(json.dumps({"error": f"Image not found at {image_path}"}))
        return
    if not os.path.exists(model_path):
        print(json.dumps({"error": f"Model not found at {model_path}"}))
        return

    try:
        model = YOLO(model_path)
        project_path = "/rails/public/analysis"
        
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        results = model.predict(
            source=image_path, 
            conf=0.25, 
            save=True, 
            project=project_path, 
            name="predict", 
            exist_ok=True,
            verbose=False 
        )
        
        if not results or len(results) == 0:
            print(json.dumps({"error": "YOLO returned no results"}))
            return

        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            conf_value = float(result.boxes.conf.mean().item()) * 100

        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты соблюдены" if is_approved else f"Нарушения: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        print(json.dumps({"error": f"Runtime error: {str(e)}"}))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])
    else:
        print(json.dumps({"error": "Missing arguments"}))