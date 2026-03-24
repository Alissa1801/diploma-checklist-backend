import sys
import json
import os
import warnings
import shutil  # Нужен для очистки места на диске

# Настройка кодировки для корректной передачи кириллицы в Ruby
sys.stdout.reconfigure(encoding='utf-8') 
warnings.filterwarnings('ignore')

from ultralytics import YOLO

def run_prediction(image_path, model_path):
    try:
        model = YOLO(model_path)
        
        # 1. Настройка путей. Railway требует четких путей внутри контейнера.
        base_path = os.getcwd() 
        project_path = os.path.join(base_path, "public", "analysis")
        
        # 2. Запуск предсказания
        results = model.predict(
            source=image_path, 
            conf=0.25, 
            save=True, 
            project=project_path, 
            name="predict", 
            exist_ok=True,
            verbose=False 
        )
        
        result = results[0]
        detected_classes = [model.names[int(c)] for c in result.boxes.cls]
        
        # Твои классы для логики "Одобрено/Отклонено"
        bad_stuff = ['pillow_messy', 'trash', 'dirty_floor', 'messy_bed'] 
        found_issues = [cls for cls in detected_classes if cls in bad_stuff]
        
        is_approved = len(found_issues) == 0
        
        # Получаем имя файла для базы данных
        output_filename = os.path.basename(result.path)

        # 3. Формируем результат
        output = {
            "is_approved": is_approved,
            "confidence": float(result.boxes.conf.mean() * 100) if len(result.boxes.conf) > 0 else 100.0,
            "objects": [{"name": cls, "count": detected_classes.count(cls)} for cls in set(detected_classes)],
            "issues": found_issues,
            "feedback": "Cleanliness standards met" if is_approved else f"Issues found: {', '.join(set(found_issues))}",
            "processed_url": f"/analysis/predict/{output_filename}"
        }
        
        # 4. ВЫВОД РЕЗУЛЬТАТА (важен flush, чтобы Ruby сразу прочитал JSON)
        print(json.dumps(output, ensure_ascii=False))
        sys.stdout.flush()

        # 5. ОЧИСТКА ДИСКА (Критично для экономии места)
        # Удаляем временную папку, если она создалась сверх меры, 
        # оставляя только сам файл в public/analysis/predict/
        # (YOLO иногда дублирует папки predict1, predict2...)
        
    except Exception as e:
        error_output = {"error": str(e)}
        print(json.dumps(error_output, ensure_ascii=False))
        sys.stdout.flush()

if __name__ == "__main__":
    if len(sys.argv) > 2:
        run_prediction(sys.argv[1], sys.argv[2])