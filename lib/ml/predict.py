import sys
import os
import json
import warnings
import shutil
import numpy as np

# Настройка вывода для корректного захвата данных сервисом Ruby
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

try:
    from ultralytics import YOLO
except ImportError as e:
    # В официальном образе Ultralytics этот импорт обязан сработать
    print(json.dumps({"error": f"YOLO library not found: {str(e)}"}))
    sys.exit(1)

def run_prediction(image_path, model_path):
    # 1. Базовые проверки наличия файлов (критично для Docker)
    if not os.path.exists(image_path):
        print(json.dumps({"error": f"Image file not found at: {image_path}"}))
        return
    if not os.path.exists(model_path):
        print(json.dumps({"error": f"Model file best.pt not found at: {model_path}"}))
        return

    try:
        # 2. Инициализация модели
        model = YOLO(model_path)
        
        # 3. Настройка путей сохранения
        # В Docker Rails корень — это /rails
        project_root = "/rails"
        project_path = os.path.join(project_root, "public", "analysis")
        
        if not os.path.exists(project_path):
            os.makedirs(project_path, exist_ok=True)
            
        # Очистка предыдущих результатов, если они есть
        save_dir = os.path.join(project_path, "predict")
        if os.path.exists(save_dir):
            try:
                shutil.rmtree(save_dir)
            except Exception:
                pass
        
        # 4. Запуск инференса (Анализ)
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
            print(json.dumps({"error": "Model returned no results"}))
            return

        result = results[0]
        # Извлекаем названия классов объектов
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # 5. Расчет уверенности (Confidence score)
        conf_value = 0.0
        if len(result.boxes.conf) > 0:
            conf_value = float(result.boxes.conf.mean().item()) * 100

        # Логика проверки стандартов отеля
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        output_filename = os.path.basename(result.path)

        # 6. Формирование финального JSON-ответа
        output = {
            "is_approved": is_approved,
            "confidence": round(conf_value, 2),
            "objects": [{"name": str(cls), "count": int(detected_classes.count(cls))} for cls in set(detected_classes)],
            "issues": list(set(found_issues)),
            "feedback": "Стандарты чистоты соблюдены" if is_approved else f"Обнаружены нарушения: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        # Печатаем ТОЛЬКО JSON в стандартный поток вывода
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()
        
    except Exception as e:
        # В случае любой ошибки выводим её структуру в JSON
        print(json.dumps({"error": f"ML Execution error: {str(e)}"}, ensure_ascii=False))
        sys.stdout.flush()

if __name__ == "__main__":
    # Ожидаем: python3 predict.py <path_to_image> <path_to_model>
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])
    else:
        print(json.dumps({"error": "Invalid arguments. Usage: predict.py <img_path> <model_path>"}))