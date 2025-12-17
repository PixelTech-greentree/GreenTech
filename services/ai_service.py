"""
AI Service with enhanced feedback and Greenify AI task generation
"""
import os
import json
import base64
from typing import Dict, List
from datetime import datetime, timedelta
from openai import AsyncOpenAI


class AIService:
    def __init__(self):
        self.client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.model = "gpt-4o"

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
        Analyze tree image with detailed feedback
        
        Returns enhanced analysis with:
        - Basic validation (is_tree, is_real_photo, is_seedling)
        - Detailed health assessment
        - Professional recommendations
        - Care instructions
        """
        self._log(f"Rasm tahlili boshlandi, hajmi: {len(image_bytes)} bytes")
        
        base64_image = base64.b64encode(image_bytes).decode('utf-8')

        prompt = """
Sen Greenify AI - professional o'simliklar va daraxtlar parvarishi bo'yicha mutaxassissan.
Rasmni batafsil tahlil qilib, FAQAT JSON formatida javob ber.

DARAXT / O'SIMLIK IDENTIFIKATSIYASI:
- Har qanday daraxt: katta, kichik, yosh, qari
- Ko'chat (nihollar)
- Buta (kustlar)
- Gullar, xonaki o'simliklar, idishdagi o'simliklar
- Bog', hovli, ko'cha, dala, ofis va xokazolardagi o'simliklar

YETUKLIK DARAJASI (faqat vizual ko'rinish asosida, taxminiy):
- "seedling":
    Juda kichik, yangi ekilgan nihol yoki ko'chat.
    Odatda balandligi taxminan 10–40 sm atrofida bo'ladi.
    Idishdagi katta xonaki daraxtlar seedling BO'LMAYDI.

- "young":
    Kichik yoki o'rta kattalikdagi daraxt/buta.
    Shoxlari bor, lekin hali juda katta emas.
    Xonaki daraxtlar (masalan, fikus, dratsena va boshqalar)
    ko'pincha "young" deb baholanadi.

- "mature":
    Katta, to'liq shakllangan daraxt yoki uy o'simligining juda rivojlangan varianti.
    Agar o'simlik baland va keng shoxli ko'rinsa, ko'pincha "mature".

KO'CHAT FLAGI:
- "is_seedling": true
    faqat VISUAL ko'rinishidan juda kichik, yangi ekilgan ko'chat/nihol bo'lsa.
- Aks holda "is_seedling": false.

SALOMATLIK BAHOLASH:
- "excellent": Barcha barglar yam-yashil, sog'lom ko'rinishda
- "healthy": Asosan yashil, mayda nuqsonlar bo'lishi mumkin
- "stressed": Sarg'ish yoki qurish alomatlari bor
- "critical": Ko'p sarg'ish/jigarrang barglar, jiddiy zarar
- "dying": Deyarli qurigan, hayot belgilari juda kam

TUPROQ NAMLIGI:
- "very_dry": Tuproq juda quruq, yoriqlar bo'lishi mumkin
- "dry": Quruq tuproq, sug'orish kerak
- "normal": O'rtacha namlik, yaxshi holat
- "wet": Ancha ho'l, yaqinda sug'orilgan
- "waterlogged": Juda ho'l, suv to'lib turgan

BATAFSIL TAHLIL:
1. O'simlikning turi va taxminiy tavsifi
2. Barglarning rangi va sifati
3. Poya/shoxlarning holati
4. Tuproq va atrof muhit holati
5. Aniq muammolar (agar sezilsa)

PROFESSIONAL TAVSIYALAR:
- Hozir qanday g'amxo'rlik kerak
- Sug'orish bo'yicha tavsiya
- Yorug'lik va joylashuv bo'yicha tavsiya
- Mumkin bo'lgan muammolarning oldini olish
- Keyingi 7–14 kun uchun qisqa reja

FAQAT JSON QAYTAR:

{
  "is_tree": true/false,
  "is_real_photo": true/false,
  "is_seedling": true/false,
  "maturity": "seedling"/"young"/"mature"/"unknown",
  "health": "excellent"/"healthy"/"stressed"/"critical"/"dying"/"unknown",
  "soil_moisture": "very_dry"/"dry"/"normal"/"wet"/"waterlogged"/"unknown",
  "detailed_analysis": {
    "plant_type": "Daraxt yoki o'simlik turi (agar aniqlansa)",
    "leaf_condition": "Barglarning batafsil tavsifi",
    "stem_condition": "Poyaning/shoxlarning holati",
    "soil_condition": "Tuproq va atrofning tavsifi",
    "problems_detected": ["Aniqlangan muammolar ro'yxati"],
    "positive_signs": ["Ijobiy ko'rsatkichlar"]
  },
  "recommendations": {
    "immediate_actions": ["Darhol qilish kerak bo'lgan ishlar"],
    "watering_schedule": "Sug'orish rejimi tavsiyasi",
    "lighting_needs": "Yorug'lik talablari",
    "next_steps": ["Keyingi 1-2 hafta uchun reja"],
    "warnings": ["Ogohlantirish va ehtiyot choralar"]
  },
  "comment": "Umumiy baho va asosiy xulosa (2-3 jumla)"
}

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
                max_tokens=1500,
                temperature=0.3
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
            
            # Validate and set defaults
            defaults = {
                "is_tree": False,
                "is_real_photo": False,
                "is_seedling": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "detailed_analysis": {
                    "plant_type": "Aniqlanmadi",
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
                "comment": "Ma'lumot yo'q"
            }
            
            for k, v in defaults.items():
                if k not in result:
                    result[k] = v
                elif isinstance(v, dict):
                    for sub_k, sub_v in v.items():
                        if sub_k not in result[k]:
                            result[k][sub_k] = sub_v

            self._log("=== GREENIFY AI TAHLIL NATIJASI ===")
            self._log(f"  🌳 Daraxt: {'HA' if result['is_tree'] else 'YO`Q'}")
            self._log(f"  📷 Haqiqiy rasm: {'HA' if result['is_real_photo'] else 'YO`Q'}")
            self._log(f"  🌱 Ko'chat: {'HA' if result['is_seedling'] else 'YO`Q'}")
            self._log(f"  📏 Yetuklik: {result['maturity']}")
            self._log(f"  💚 Salomatlik: {result['health']}")
            self._log(f"  💧 Tuproq namligi: {result['soil_moisture']}")
            self._log("=====================================")

            return result

        except json.JSONDecodeError as e:
            self._log(f"JSON parse xatosi: {e}")
            return self._get_default_error_response("Tahlil xatosi - javob noto'g'ri formatda")
        except Exception as e:
            self._log(f"Greenify AI xatolik: {type(e).__name__}: {e}")
            raise

    async def compare_images(
        self,
        previous_image_bytes: bytes,
        current_image_bytes: bytes
    ) -> Dict:
        """
        Compare two images with detailed change analysis
        """
        self._log(f"Ikki rasm solishtirilmoqda")
        
        base64_prev = base64.b64encode(previous_image_bytes).decode('utf-8')
        base64_curr = base64.b64encode(current_image_bytes).decode('utf-8')

        prompt = """Sen Greenify AI - professional o'simliklar mutaxassisissan.
Ikki rasmni solishtir va batafsil tahlil ber. FAQAT JSON qaytar.

BIRINCHI RASM - OLDINGI holat
IKKINCHI RASM - HOZIRGI holat

TEKSHIRISH:
1. Bir xil daraxt/o'simlikmi?
2. Qanday o'zgarishlar bo'lgan?
3. Holat yaxshilandimi yoki yomonlashdimi?
4. Muammolar paydo bo'ldimi?

same_scene = true FAQAT agar:
- Xuddi bir xil rasm (nusxa)
- Yoki aynan bir xil burchak, vaqt (firibgarlik)

BATAFSIL O'ZGARISHLAR:
- Barglar holati (rang, miqdor, sifat)
- O'sish dinamikasi
- Tuproq namligi o'zgarishi
- Yangi muammolar yoki yaxshilanishlar
- Umumiy salomatlik tendentsiyasi

TAVSIYALAR:
- Hozirgi holatni saqlab qolish uchun
- Yomonlashuv sabablari
- Tuzatish choralari

{
  "is_tree": true/false,
  "is_real_photo": true/false,
  "is_seedling": true/false,
  "same_scene": true/false,
  "maturity": "seedling"/"young"/"mature"/"unknown",
  "health": "excellent"/"healthy"/"stressed"/"critical"/"dying"/"unknown",
  "soil_moisture": "very_dry"/"dry"/"normal"/"wet"/"waterlogged"/"unknown",
  "comparison": {
    "health_change": "improved"/"worsened"/"stable"/"unknown",
    "growth_detected": true/false,
    "moisture_change": "increased"/"decreased"/"stable"/"unknown",
    "new_problems": ["Yangi muammolar ro'yxati"],
    "improvements": ["Yaxshilanishlar ro'yxati"],
    "overall_trend": "positive"/"negative"/"neutral"
  },
  "detailed_changes": {
    "leaves": "Barglardagi o'zgarishlar",
    "stem": "Poya/novdadagi o'zgarishlar", 
    "soil": "Tuproqdagi o'zgarishlar",
    "environment": "Atrofdagi o'zgarishlar"
  },
  "recommendations": {
    "continue_actions": ["Davom ettirish kerak bo'lgan ishlar"],
    "new_actions": ["Yangi qilish kerak bo'lgan ishlar"],
    "warnings": ["Ogohlantirishlar"]
  },
  "changes": "Qisqa o'zgarishlar xulosa",
  "comment": "Umumiy baho va tavsiya"
}"""

        try:
            self._log("Greenify AI solishtirish so'rovi yuborilmoqda...")
            
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "OLDINGI RASM:"},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_prev}", "detail": "low"}
                            },
                            {"type": "text", "text": "HOZIRGI RASM:"},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_curr}"}
                            },
                            {"type": "text", "text": prompt}
                        ]
                    }
                ],
                max_tokens=1500,
                temperature=0.3
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
            
            # Set defaults
            defaults = {
                "is_tree": False,
                "is_real_photo": False,
                "is_seedling": False,
                "same_scene": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "comparison": {
                    "health_change": "unknown",
                    "growth_detected": False,
                    "moisture_change": "unknown",
                    "new_problems": [],
                    "improvements": [],
                    "overall_trend": "neutral"
                },
                "detailed_changes": {
                    "leaves": "Aniqlanmadi",
                    "stem": "Aniqlanmadi",
                    "soil": "Aniqlanmadi",
                    "environment": "Aniqlanmadi"
                },
                "recommendations": {
                    "continue_actions": [],
                    "new_actions": [],
                    "warnings": []
                },
                "changes": "Aniqlanmadi",
                "comment": "Ma'lumot yo'q"
            }
            
            for k, v in defaults.items():
                if k not in result:
                    result[k] = v
                elif isinstance(v, dict):
                    for sub_k, sub_v in v.items():
                        if sub_k not in result[k]:
                            result[k][sub_k] = sub_v

            self._log("=== SOLISHTIRISH NATIJASI ===")
            self._log(f"  Holat o'zgarishi: {result['comparison']['health_change']}")
            self._log(f"  Umumiy tendentsiya: {result['comparison']['overall_trend']}")
            self._log("=============================")

            return result

        except Exception as e:
            self._log(f"Greenify AI solishtirish xatolik: {type(e).__name__}: {e}")
            raise

    async def generate_care_tasks(
        self,
        health: str,
        soil_moisture: str,
        maturity: str,
        age_days: int,
        current_date: datetime
    ) -> List[Dict]:
        """
        AI-powered task generation based on plant condition
        Returns list of tasks with specific dates and instructions
        """
        self._log(f"Greenify AI vazifalar generatsiya qilinmoqda...")
        self._log(f"  Salomatlik: {health}")
        self._log(f"  Tuproq namligi: {soil_moisture}")
        self._log(f"  Yetuklik: {maturity}")
        self._log(f"  Yoshi: {age_days} kun")

        prompt = f"""Sen Greenify AI - professional o'simliklar parvarishi mutaxassisissan.

DARAXT HOLATI:
- Salomatlik: {health}
- Tuproq namligi: {soil_moisture}
- Yetuklik: {maturity}
- Yoshi: {age_days} kun
- Bugungi sana: {current_date.strftime('%Y-%m-%d')}

VAZIFALAR YARATISH:
Daraxtning holatiga qarab keyingi 14 kun uchun aniq vazifalar reja qil.

VAZIFA TURLARI:
1. watering - Sug'orish
2. photo_check - Holat tekshiruvi
3. fertilizing - O'g'itlash
4. pruning - Qirqish/tozalash
5. pest_check - Zararkunandalar tekshiruvi
6. support - Tayoqqa bog'lash

HAR BIR VAZIFA UCHUN:
- Aniq sana (YYYY-MM-DD format)
- Vazifa turi
- Batafsil tavsiya
- Ball (10-50 oralig'ida, qiyinlikka qarab)

QOIDALAR:
- Juda quruq tuproq uchun tezroq sug'orish
- Critical holatda har kuni tekshirish
- Yosh ko'chat uchun tez-tez parvarish
- Katta daraxt uchun kamroq lekin chuqurroq g'amxo'rlik

FAQAT JSON QAYTAR:
{
  "tasks": [
    {
      "type": "watering",
      "due_date": "2024-01-15",
      "description": "Batafsil tavsiya (o'zbek tilida)",
      "points": 30,
      "priority": "high"/"medium"/"low"
    }
  ],
  "general_advice": "Umumiy parvarish bo'yicha maslahat"
}"""

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=1000,
                temperature=0.4
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
            # Fallback to default tasks
            return self._generate_fallback_tasks(health, soil_moisture, maturity, age_days, current_date)

    def _generate_fallback_tasks(
        self,
        health: str,
        soil_moisture: str,
        maturity: str,
        age_days: int,
        current_date: datetime
    ) -> List[Dict]:
        """Fallback task generation if AI fails"""
        tasks = []
        
        # Watering task
        if soil_moisture in ["very_dry", "dry"]:
            days = 1
        elif maturity == "seedling":
            days = 2
        else:
            days = 5
        
        tasks.append({
            "type": "watering",
            "due_date": (current_date + timedelta(days=days)).strftime('%Y-%m-%d'),
            "description": f"Daraxtni yaxshilab sug'oring. Tuproq namligini tekshiring.",
            "points": 30,
            "priority": "high" if soil_moisture in ["very_dry", "dry"] else "medium"
        })
        
        # Photo check
        check_days = 1 if health == "critical" else 3 if maturity == "seedling" else 7
        tasks.append({
            "type": "photo_check",
            "due_date": (current_date + timedelta(days=check_days)).strftime('%Y-%m-%d'),
            "description": "Daraxt holatini tekshiring va rasmga oling.",
            "points": 20,
            "priority": "high" if health == "critical" else "medium"
        })
        
        return tasks

    def _get_default_error_response(self, error_message: str) -> Dict:
        """Default error response"""
        return {
            "is_tree": False,
            "is_real_photo": False,
            "is_seedling": False,
            "maturity": "unknown",
            "health": "unknown",
            "soil_moisture": "unknown",
            "detailed_analysis": {
                "plant_type": "Aniqlanmadi",
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
