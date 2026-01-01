"""
AI Service with enhanced feedback and Greenify AI task generation
GPT-5 model with improved plant/flower detection
FIXED: max_tokens -> max_completion_tokens for GPT-5
"""
import os
import json
import base64
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from openai import AsyncOpenAI


class AIService:
    def __init__(self):
        self.client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        # GPT-5 model - eng kuchli va yangi
        self.model = "gpt-5"

    def _log(self, message: str, data: any = None):
        """Print log with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [Greenify AI] {message}")
        if data:
            if isinstance(data, dict):
                print(f"[{timestamp}] [Greenify AI] Data: {json.dumps(data, ensure_ascii=False, indent=2)}")
            else:
                print(f"[{timestamp}] [Greenify AI] Data: {data}")

    async def analyze_single_image(self, image_bytes: bytes) -> Dict:
        """
        Analyze plant/tree/flower image with detailed feedback
        
        QABUL QILINADIGAN:
        - Ko'chatlar (har qanday o'lcham)
        - Yosh daraxtlar (2.5 metrdan past)
        - Xonaki gullar (tuvakda ham bo'lsa)
        - Idishdagi o'simliklar
        - Sabzavot ko'chatlari
        - Gullar, butalar
        
        RAD ETILADIGAN:
        - Katta daraxtlar (2.5+ metr YOKI yo'g'on tana)
        - O'simlik bo'lmagan narsalar
        - Fake/internet rasmlar
        """
        self._log(f"Rasm tahlili boshlandi, hajmi: {len(image_bytes)} bytes")
        
        base64_image = base64.b64encode(image_bytes).decode('utf-8')

        prompt = """
Sen Greenify AI - professional botanik va o'simliklar mutaxassisissan.
Rasmni JUDA SINCHIKLAB tahlil qil va FAQAT JSON formatida javob ber.

═══════════════════════════════════════════════════════════════
                    QABUL QILINADIGAN O'SIMLIKLAR
═══════════════════════════════════════════════════════════════

✅ KO'CHATLAR va NIHOLLAR (har qanday kichik o'simlik)
✅ YOSH DARAXTLAR (2.5 metrdan PAST, ingichka tana)
✅ XONAKI GULLAR (orxideya, fikus, monstera, sansevieriya, va h.k.)
   - Tuvakda (gorshokda) bo'lsa HAM qabul qilinadi
   - Tuvak balandligi hisobga olinMAYDI
✅ SUKKULENTLAR va KAKTUSLAR
✅ SABZAVOT KO'CHATLARI (pomidor, bodring, qalampir ko'chati)
✅ GULLAR (atirgul, lola, boychechak va h.k.)
✅ BUTALAR (kichik)

═══════════════════════════════════════════════════════════════
                    RAD ETILADIGAN NARSALAR
═══════════════════════════════════════════════════════════════

❌ KATTA DARAXTLAR:
   - Balandligi 2.5 metrdan oshgan
   - YO'G'ON TANALI (diametr 10+ sm) - bu odam ekmagan, tabiiy o'sgan
   - Qalin shoxlar va katta toj

❌ O'SIMLIK EMAS:
   - Mebel, texnika, hayvonlar, odamlar
   - Oziq-ovqat (mevalar, sabzavotlar - tayyor mahsulot)
   - Quritilgan gullar yoki sun'iy o'simliklar

❌ FAKE RASMLAR:
   - Internet/stock rasmlar
   - Screenshot
   - Suratdan surat

═══════════════════════════════════════════════════════════════
                    BALANDLIK VA TANA QALINLIGI
═══════════════════════════════════════════════════════════════

BALANDLIKNI ANIQLASH:
- Tuvak/gorshok balandligini HISOBGA OLMA
- Faqat O'SIMLIKNING O'ZI balandligi
- Odamlar yoki boshqa ob'ektlar bilan solishtir
- Barglar o'lchami va poya qalinligiga qara

TANA QALINLIGI (MUHIM!):
- Ingichka poya (< 3 sm) = yangi ekilgan, QABUL
- O'rtacha poya (3-10 sm) = yosh daraxt, QABUL
- Yo'g'on tana (10+ sm) = eski daraxt, RAD ET
- Yo'g'on tanali daraxt = ODAM EKMAGAN, tabiatda o'sgan

O'SIMLIK TURINI ANIQLASH:
- Iloji bo'lsa aniq nomini yoz (masalan: "Fikus elastika", "Monstera deliciosa")
- Aniqlay olmasang, umumiy turini yoz ("Xonaki palma", "Yosh terak ko'chati")

═══════════════════════════════════════════════════════════════

JSON JAVOB FORMATI:

{
  "is_plant": true/false,
  "is_real_photo": true/false,
  "is_acceptable": true/false,
  "rejection_reason": null/"TOO_BIG"/"TOO_THICK"/"NOT_PLANT"/"FAKE",
  
  "plant_info": {
    "name_latin": "Lotincha nomi (agar aniqlansa)",
    "name_uzbek": "O'zbekcha nomi",
    "name_common": "Umumiy nomi",
    "category": "houseplant/seedling/young_tree/flower/succulent/vegetable/bush/unknown"
  },
  
  "size_analysis": {
    "estimated_height_cm": 0,
    "trunk_diameter_cm": 0,
    "pot_included": true/false,
    "height_without_pot_cm": 0,
    "is_too_tall": false,
    "is_trunk_too_thick": false
  },
  
  "maturity": "seedling/young/mature/houseplant",
  "health": "excellent/healthy/stressed/critical/dying/unknown",
  "soil_moisture": "very_dry/dry/normal/wet/waterlogged/unknown",
  
  "detailed_analysis": {
    "leaf_condition": "Barglar holati",
    "stem_condition": "Poya/tana holati",
    "soil_condition": "Tuproq holati",
    "root_visible": false,
    "problems_detected": [],
    "positive_signs": []
  },
  
  "recommendations": {
    "immediate_actions": [],
    "watering_schedule": "Sug'orish tavsiyasi",
    "lighting_needs": "Yorug'lik talabi",
    "next_steps": [],
    "warnings": []
  },
  
  "comment": "Batafsil xulosa (o'simlik nomi, holati, tavsiyalar)",
  
  "is_tree": true/false,
  "is_seedling": true/false
}

MUHIM QOIDALAR:
1. is_acceptable = true FAQAT agar o'simlik va to'g'ri o'lchamda bo'lsa
2. Tuvak/gorshok balandligini O'SIMLIK balandligiga QO'SHMA
3. Yo'g'on tanali daraxt = tabiiy o'sgan, odam ekmagan = RAD
4. Xonaki gul tuvakda = DOIM QABUL (agar haqiqiy o'simlik bo'lsa)
5. O'simlik nomini iloji boricha aniqla
"""

        try:
            self._log("Greenify AI API ga so'rov yuborilmoqda...")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                max_completion_tokens=2500,  # GPT-5 uchun to'g'ri parametr
            
            )

            content = response.choices[0].message.content.strip()
            self._log(f"Greenify AI javob berdi")

            # Clean JSON
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()

            result = json.loads(content)
            
            # Process result
            result = self._process_analysis_result(result)

            self._log("=== GREENIFY AI TAHLIL NATIJASI ===")
            self._log(f"  🌿 O'simlik: {'HA' if result.get('is_plant') else 'YO`Q'}")
            self._log(f"  ✅ Qabul: {'HA' if result.get('is_acceptable') else 'YO`Q'}")
            if result.get('rejection_reason'):
                self._log(f"  ❌ Rad sababi: {result.get('rejection_reason')}")
            plant_info = result.get('plant_info', {})
            self._log(f"  🌱 Nomi: {plant_info.get('name_uzbek', 'Noma`lum')}")
            self._log(f"  📏 Balandlik: ~{result.get('size_analysis', {}).get('height_without_pot_cm', 0)} sm")
            self._log(f"  🌳 Yetuklik: {result.get('maturity')}")
            self._log(f"  💚 Salomatlik: {result.get('health')}")
            self._log("=====================================")

            return result

        except json.JSONDecodeError as e:
            self._log(f"JSON parse xatosi: {e}")
            return self._get_default_error_response("Tahlil xatosi - javob noto'g'ri formatda")
        except Exception as e:
            self._log(f"Greenify AI xatolik: {type(e).__name__}: {e}")
            raise

    def _process_analysis_result(self, result: Dict) -> Dict:
        """Process and validate analysis result"""
        
        # Default values
        defaults = {
            "is_plant": False,
            "is_real_photo": True,
            "is_acceptable": False,
            "rejection_reason": None,
            "plant_info": {
                "name_latin": None,
                "name_uzbek": "Noma'lum",
                "name_common": "Noma'lum",
                "category": "unknown"
            },
            "size_analysis": {
                "estimated_height_cm": 0,
                "trunk_diameter_cm": 0,
                "pot_included": False,
                "height_without_pot_cm": 0,
                "is_too_tall": False,
                "is_trunk_too_thick": False
            },
            "maturity": "unknown",
            "health": "unknown",
            "soil_moisture": "unknown",
            "detailed_analysis": {
                "leaf_condition": "Ma'lumot yo'q",
                "stem_condition": "Ma'lumot yo'q",
                "soil_condition": "Ma'lumot yo'q",
                "root_visible": False,
                "problems_detected": [],
                "positive_signs": []
            },
            "recommendations": {
                "immediate_actions": [],
                "watering_schedule": "Ma'lumot yo'q",
                "lighting_needs": "Ma'lumot yo'q",
                "next_steps": [],
                "warnings": []
            },
            "comment": "Ma'lumot yo'q",
            "is_tree": False,
            "is_seedling": False
        }
        
        # Apply defaults
        for k, v in defaults.items():
            if k not in result:
                result[k] = v
            elif isinstance(v, dict):
                for sub_k, sub_v in v.items():
                    if sub_k not in result.get(k, {}):
                        if k not in result:
                            result[k] = {}
                        result[k][sub_k] = sub_v

        # Backward compatibility
        if result.get("is_acceptable") and not result.get("is_tree"):
            result["is_tree"] = True
        
        if result.get("is_plant") and not result.get("is_tree"):
            result["is_tree"] = True

        # Build comment with plant name
        plant_info = result.get("plant_info", {})
        plant_name = plant_info.get("name_uzbek") or plant_info.get("name_common") or "Noma'lum o'simlik"
        
        if result.get("is_acceptable"):
            health = result.get("health", "unknown")
            health_uz = {
                "excellent": "a'lo",
                "healthy": "sog'lom",
                "stressed": "stressda",
                "critical": "tanqidiy",
                "dying": "so'liyapti"
            }.get(health, "noma'lum")
            
            if not result.get("comment") or result.get("comment") == "Ma'lumot yo'q":
                result["comment"] = f"{plant_name} - holati {health_uz}. "
                if result.get("recommendations", {}).get("immediate_actions"):
                    result["comment"] += "Tavsiya: " + ", ".join(result["recommendations"]["immediate_actions"][:2])

        return result

    async def compare_images_for_task(
        self,
        previous_image_bytes: bytes,
        current_image_bytes: bytes,
        task_type: str = "watering"
    ) -> Dict:
        """
        Compare two images for task completion
        Checks if same plant and analyzes changes
        """
        self._log(f"Vazifa uchun ikki rasm solishtirilmoqda, vazifa turi: {task_type}")
        
        base64_prev = base64.b64encode(previous_image_bytes).decode('utf-8')
        base64_curr = base64.b64encode(current_image_bytes).decode('utf-8')

        prompt = f"""Sen Greenify AI - professional botanik mutaxassisissan.
Ikki rasmni solishtir va FAQAT JSON qaytar.

BIRINCHI RASM - OLDINGI holat (ro'yxatdan o'tkazilgan o'simlik)
IKKINCHI RASM - HOZIRGI holat (vazifa uchun yuborilgan)

VAZIFA TURI: {task_type}

═══════════════════════════════════════════════════════════════
                    TEKSHIRISH KERAK
═══════════════════════════════════════════════════════════════

1. BIR XIL O'SIMLIKMI?
   - Barg shakli va rangi o'xshashmi?
   - Poya/tana o'xshashmi?
   - Tuvak/gorshok o'xshashmi?
   - Umumiy ko'rinish o'xshashmi?

2. HAQIQIY RASMMI?
   - Internet/fake emas
   - Bir xil vaqtda olingan emas (firibgarlik)

3. VAZIFAGA MOS KELISHINI TEKSHIR:
   - watering: Tuproq ho'l ko'rinishi kerak
   - photo_check: O'simlik ko'rinishi kerak
   - Boshqa: Umumiy holat

═══════════════════════════════════════════════════════════════

{{
  "is_same_plant": true/false,
  "confidence_percent": 0-100,
  "is_real_photo": true/false,
  "is_fraud_attempt": true/false,
  "fraud_reason": null/"SAME_IMAGE"/"INTERNET_IMAGE"/"DIFFERENT_PLANT",
  
  "plant_match_details": {{
    "leaf_match": true/false,
    "stem_match": true/false,
    "pot_match": true/false,
    "overall_match": true/false,
    "differences_found": []
  }},
  
  "current_analysis": {{
    "is_plant": true/false,
    "health": "excellent/healthy/stressed/critical/dying/unknown",
    "soil_moisture": "very_dry/dry/normal/wet/waterlogged/unknown",
    "maturity": "seedling/young/mature/houseplant"
  }},
  
  "comparison": {{
    "health_change": "improved/worsened/stable/unknown",
    "growth_detected": true/false,
    "moisture_change": "increased/decreased/stable/unknown",
    "visible_changes": []
  }},
  
  "task_validation": {{
    "task_type": "{task_type}",
    "task_completed_properly": true/false,
    "validation_notes": "Izoh"
  }},
  
  "recommendations": {{
    "continue_actions": [],
    "new_actions": [],
    "warnings": []
  }},
  
  "comment": "Xulosa",
  
  "is_tree": true/false,
  "same_scene": true/false
}}

MUHIM:
1. is_same_plant = true FAQAT agar aniq bir xil o'simlik bo'lsa
2. is_fraud_attempt = true agar firibgarlik aniqlansa
3. same_scene = true FAQAT agar xuddi bir xil rasm (nusxa)
"""

        try:
            self._log("Greenify AI solishtirish so'rovi yuborilmoqda...")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "OLDINGI RASM (ro'yxatdagi o'simlik):"},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_prev}", "detail": "high"}
                            },
                            {"type": "text", "text": "HOZIRGI RASM (vazifa uchun yuborilgan):"},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_curr}", "detail": "high"}
                            },
                            {"type": "text", "text": prompt}
                        ]
                    }
                ],
                max_completion_tokens=2000
                          )

            content = response.choices[0].message.content.strip()
            
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()

            result = json.loads(content)
            
            # Backward compatibility
            if "is_same_plant" in result:
                result["is_tree"] = result.get("current_analysis", {}).get("is_plant", True)
                result["is_real_photo"] = result.get("is_real_photo", True)
                result["health"] = result.get("current_analysis", {}).get("health", "unknown")
                result["soil_moisture"] = result.get("current_analysis", {}).get("soil_moisture", "unknown")
                result["maturity"] = result.get("current_analysis", {}).get("maturity", "unknown")
                
                # same_scene for fraud detection
                if result.get("is_fraud_attempt") and result.get("fraud_reason") == "SAME_IMAGE":
                    result["same_scene"] = True
                else:
                    result["same_scene"] = result.get("same_scene", False)

            self._log("=== SOLISHTIRISH NATIJASI ===")
            self._log(f"  🌱 Bir xil o'simlik: {'HA' if result.get('is_same_plant') else 'YO`Q'} ({result.get('confidence_percent', 0)}%)")
            self._log(f"  🚨 Firibgarlik: {'HA' if result.get('is_fraud_attempt') else 'YO`Q'}")
            self._log(f"  📋 Vazifa bajarildi: {'HA' if result.get('task_validation', {}).get('task_completed_properly') else 'YO`Q'}")
            self._log("=============================")

            return result

        except Exception as e:
            self._log(f"Greenify AI solishtirish xatolik: {type(e).__name__}: {e}")
            # Default - qabul qilish (xatolik bo'lsa)
            return {
                "is_same_plant": True,
                "confidence_percent": 50,
                "is_real_photo": True,
                "is_fraud_attempt": False,
                "is_tree": True,
                "same_scene": False,
                "health": "healthy",
                "soil_moisture": "normal",
                "maturity": "unknown",
                "comparison": {
                    "health_change": "stable",
                    "growth_detected": False,
                    "moisture_change": "stable"
                },
                "comment": "Tahlil xatosi, lekin davom ettirildi"
            }

    async def compare_images(
        self,
        previous_image_bytes: bytes,
        current_image_bytes: bytes
    ) -> Dict:
        """
        Legacy method - redirects to compare_images_for_task
        """
        return await self.compare_images_for_task(
            previous_image_bytes,
            current_image_bytes,
            task_type="photo_check"
        )

    async def generate_care_tasks(
        self,
        health: str,
        soil_moisture: str,
        maturity: str,
        age_days: int,
        current_date: datetime,
        plant_type: str = "unknown"
    ) -> List[Dict]:
        """
        AI-powered task generation based on plant condition
        """
        self._log(f"Greenify AI vazifalar generatsiya qilinmoqda...")
        self._log(f"  Salomatlik: {health}")
        self._log(f"  Tuproq namligi: {soil_moisture}")
        self._log(f"  Yetuklik: {maturity}")
        self._log(f"  O'simlik turi: {plant_type}")

        # Format date properly for JSON
        current_date_str = current_date.strftime('%Y-%m-%d')

        prompt = f"""Sen Greenify AI - professional o'simliklar parvarishi mutaxassisissan.

O'SIMLIK HOLATI:
- Turi: {plant_type}
- Salomatlik: {health}
- Tuproq namligi: {soil_moisture}
- Yetuklik: {maturity}
- Yoshi: {age_days} kun
- Bugungi sana: {current_date_str}

VAZIFALAR YARATISH (keyingi 14 kun uchun):

VAZIFA TURLARI:
1. watering - Sug'orish
2. photo_check - Holat tekshiruvi
3. fertilizing - O'g'itlash
4. pruning - Qirqish/tozalash
5. pest_check - Zararkunandalar
6. repotting - Qayta ekish

O'SIMLIK TURIGA QARAB:
- Xonaki gul: Ko'proq namlik
- Ko'chat: Tez-tez sug'orish
- Sukkulent/kaktus: Kam sug'orish
- Yosh daraxt: O'rtacha parvarish

Sanalarni YYYY-MM-DD formatida ber.

FAQAT JSON QAYTAR:
{{
  "tasks": [
    {{
      "type": "watering",
      "due_date": "{current_date_str}",
      "description": "Tavsiya (o'zbek tilida)",
      "points": 30,
      "priority": "high"
    }}
  ],
  "general_advice": "Umumiy maslahat"
}}"""

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                max_completion_tokens=1500
            )

            content = response.choices[0].message.content.strip()
            
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()

            result = json.loads(content)
            
            self._log(f"  Yaratildi: {len(result.get('tasks', []))} ta vazifa")
            
            return result.get('tasks', [])

        except Exception as e:
            self._log(f"Greenify AI task generation xatolik: {type(e).__name__}: {e}")
            return self._generate_fallback_tasks(health, soil_moisture, maturity, age_days, current_date, plant_type)

    def _generate_fallback_tasks(
        self,
        health: str,
        soil_moisture: str,
        maturity: str,
        age_days: int,
        current_date: datetime,
        plant_type: str = "unknown"
    ) -> List[Dict]:
        """Fallback task generation if AI fails"""
        tasks = []
        
        # Sug'orish vazifasi
        if soil_moisture in ["very_dry", "dry"]:
            days = 1
        elif plant_type in ["succulent", "cactus"]:
            days = 10
        elif maturity == "seedling":
            days = 2
        elif maturity == "houseplant":
            days = 4
        else:
            days = 5
        
        watering_date = current_date + timedelta(days=days)
        tasks.append({
            "type": "watering",
            "due_date": watering_date.strftime('%Y-%m-%d'),
            "description": "O'simlikni yaxshilab sug'oring. Tuproq namligini tekshiring.",
            "points": 30,
            "priority": "high" if soil_moisture in ["very_dry", "dry"] else "medium"
        })
        
        # Photo check
        check_days = 1 if health == "critical" else 3 if maturity == "seedling" else 7
        check_date = current_date + timedelta(days=check_days)
        tasks.append({
            "type": "photo_check",
            "due_date": check_date.strftime('%Y-%m-%d'),
            "description": "O'simlik holatini tekshiring va rasmga oling.",
            "points": 20,
            "priority": "high" if health == "critical" else "medium"
        })
        
        return tasks

    def _get_default_error_response(self, error_message: str) -> Dict:
        """Default error response"""
        return {
            "is_plant": False,
            "is_tree": False,
            "is_real_photo": False,
            "is_acceptable": False,
            "rejection_reason": "ERROR",
            "plant_info": {
                "name_latin": None,
                "name_uzbek": "Aniqlanmadi",
                "name_common": "Aniqlanmadi",
                "category": "unknown"
            },
            "size_analysis": {
                "estimated_height_cm": 0,
                "trunk_diameter_cm": 0,
                "pot_included": False,
                "height_without_pot_cm": 0,
                "is_too_tall": False,
                "is_trunk_too_thick": False
            },
            "maturity": "unknown",
            "health": "unknown",
            "soil_moisture": "unknown",
            "is_seedling": False,
            "detailed_analysis": {
                "leaf_condition": "Ma'lumot yo'q",
                "stem_condition": "Ma'lumot yo'q",
                "soil_condition": "Ma'lumot yo'q",
                "problems_detected": [],
                "positive_signs": []
            },
            "recommendations": {
                "immediate_actions": [],
                "watering_schedule": "Ma'lumot yo'q",
                "lighting_needs": "Ma'lumot yo'q",
                "next_steps": [],
                "warnings": []
            },
            "comment": error_message
        }
