import sys
import os
import json
import warnings
import shutil

# --- УЛЬТИМАТИВНЫЙ ЯДЕРНЫЙ ФИКС NUMPY & OPENCV (FINAL REPAIR) ---
try:
    import numpy as np
    
    # 1. ФИКС AttributeError: 'numpy._globals' has no attribute '_signature_descriptor'
    if not hasattr(np, '_globals'):
        class MockGlobals:
            _signature_descriptor = None
        np._globals = MockGlobals()
    elif not hasattr(np._globals, '_signature_descriptor'):
        np._globals._signature_descriptor = None

    # 2. РЕШЕНИЕ ОШИБКИ: expected np.ndarray (got numpy.ndarray)
    actual_ndarray_type = type(np.array([]))
    np.ndarray = actual_ndarray_type
    
    # 3. Регистрация фикса в системных модулях
    sys.modules['np'] = np
    
    # 4. Фикс для старых C-расширений
    if hasattr(np, "core"):
        sys.modules['numpy.core.multiarray'] = np.core.multiarray
    
    # 5. Восстановление удаленных в Numpy 2.0 алиасов типов
    if not hasattr(np, "float_"): np.float_ = np.float64
    if not hasattr(np, "int_"): np.int_ = np.int64

except Exception as e:
    print(json.dumps({"error": f"Critical Infra Fix Failed: {str(e)}"}))
    sys.exit(1)

# Настройка вывода для Ruby (UTF-8)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

# Импортируем YOLO только после всех хаков
try:
    from ultralytics import YOLO
except Exception as e:
    print(json.dumps({"error": f"YOLO Library Import Failed: {str(e)}"}))
    sys.exit(1)

def run_prediction(image_path, model_path):
    # ПРОВЕРКА 1: Существование фото
    if not os.path.exists(image_path):
        print(json.dumps({"error": f"Image file not found at {image_path}"}))
        return

    # ПРОВЕРКА 2: Существование модели
    if not os.path.exists(model_path):
        print(json.dumps({"error": f"Model file not found at {model_path}"}))
        return

    try:
        # 1. Инициализация модели
        model = YOLO(model_path)
        
        # 2. Настройка путей сохранения
        base_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        project_path = os.path.join(base_path, "public", "analysis")
        
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        save_dir = os.path.join(project_path, "predict")
        if os.path.exists(save_dir):
            try:
                shutil.rmtree(save_dir)
            except:
                pass
        
        # 3. Запуск анализа
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
        
        # 4. Логика оценки (отель)
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            conf_value = float(result.boxes.conf.mean().item()) * 100

        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 5. Формирование ответа
        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты чистоты соблюдены" if is_approved else f"Обнаружены проблемы: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        print(json.dumps({"error": f"Prediction error: {str(e)}"}))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])
    else:
        print(json.dumps({"error": "Missing arguments. Usage: predict.py <image> <model>"}))