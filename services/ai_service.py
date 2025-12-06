"""
AI Service for analyzing tree images using OpenAI GPT-4o Vision
"""
import os
import json
import base64
from typing import Optional, Dict
from openai import AsyncOpenAI


class AIService:
    def __init__(self):
        self.client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.model = "gpt-4o"
    
    async def analyze_single_image(self, image_bytes: bytes) -> Dict:
        """
        Analyze a single tree image.
        
        Returns structured JSON with:
        - is_seedling: bool
        - maturity: seedling/young/mature/unknown
        - health: healthy/stressed/critical/unknown
        - soil_moisture: dry/normal/wet/unknown
        - comment: short explanation in Uzbek (Latin)
        """
        base64_image = base64.b64encode(image_bytes).decode('utf-8')
        
        prompt = """Ushbu rasmni tahlil qiling va FAQAT JSON formatida javob bering (hech qanday qo'shimcha matn yo'q).

Javob formati:
{
  "is_seedling": true yoki false,
  "maturity": "seedling" yoki "young" yoki "mature" yoki "unknown",
  "health": "healthy" yoki "stressed" yoki "critical" yoki "unknown",
  "soil_moisture": "dry" yoki "normal" yoki "wet" yoki "unknown",
  "comment": "O'zbek tilida qisqa izoh (2-3 jumla)"
}
Mezonlar (diqqat bilan amal qiling):

- is_seedling:
  - true bo'lsin agar:
    - bu yangi ekilgan yoki yaqin vaqtda ko'chirilgan ko'chat bo'lsa,
    - daraxt hali juda katta bo'lmasa (odatda ingichka tanali, balandligi taxminan 0.5–2.5 metr oralig'ida bo'lishi mumkin),
    - atrofida yangi kovlangan tuproq, ko'milgan ildiz joyi, ketmon/belkurak yoki ekish jarayoni alomatlari ko'rinsa.
  - false bo'lsin agar:
    - bu juda katta, qalin tanali, eski daraxt bo'lsa (park/bog'dagi yillar davomida o'sgan daraxt),
    - yoki umuman daraxt emas (bino, avtomobil, boshqa obyekt).

- maturity:
  - "seedling": yangi ekilgan yoki juda yosh ko'chat; tanasi nisbatan ingichka, kattalashib ulgurmagan. Balandligi kichik bo'lishi shart emas, 0.5–2.5 metr atrofida bo'lishi mumkin, lekin ko'rinishi bo'yicha hali yosh.
  - "young": biroz kattaroq, lekin hali to'liq voyaga yetmagan daraxt; tanasi o'rtacha qalin, shoxlari ko'proq, lekin baribir yosh ko'rinishda.
  - "mature": ancha katta, qalin tanali, soya beradigan daraxt; odatda yillar davomida o'sgan ko'rinadi.
  - "unknown": balandlik yoki yoshni aniq baholab bo'lmasa.

- health:
  - Barglar, shoxlar va tananing holatiga qarab:
    - "healthy": umumiy ko'rinishi sog'lom, jiddiy zarar yo'q.
    - "stressed": biroz qurish, zararkunanda yoki yetarli parvarish bo'lmagani belgilari bor.
    - "critical": jiddiy kasallangan, ko'p qismi qurigan yoki juda yomon holatda.
    - "unknown": baholash qiyin bo'lsa.

- soil_moisture:
  - Tuproqning ko'rinishiga qarang:
    - "dry": tuproq juda quruq, yorilgan yoki umuman namlik sezilmaydi.
    - "normal": tuproqda yetarli namlik bor, lekin loy bo'lib ketmagan.
    - "wet": tuproq juda nam, ho'l yoki loy holatida.
    - "unknown": tuproq aniq ko'rinmasa.

- comment:
  - O'zbek tilida (lotin alifbosida) 2–3 jumla bilan qisqa izoh bering:
    - daraxtning umumiy holati,
    - agar kerak bo'lsa, parvarish bo'yicha 1–2 tavsiya.
FAQAT JSON javob bering, boshqa hech narsa yo'q!"""

        try:
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
                max_tokens=800,
                temperature=0.1
            )
            
            content = response.choices[0].message.content
            
            # Clean response (remove markdown code blocks if any)
            content = content.strip()
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()
            
            # Parse JSON
            result = json.loads(content)
            
            # Validate required fields
            required_fields = ["is_seedling", "maturity", "health", "soil_moisture", "comment"]
            for field in required_fields:
                if field not in result:
                    result[field] = "unknown" if field != "is_seedling" else False
                    if field == "comment":
                        result[field] = "Ma'lumot yo'q"
            
            return result
        
        except json.JSONDecodeError as e:
            print(f"JSON parse error: {e}, content: {content}")
            # Return default values if parsing fails
            return {
                "is_seedling": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "comment": "Rasmni tahlil qilishda xatolik yuz berdi"
            }
        except Exception as e:
            print(f"AI service error: {e}")
            raise
    
    async def compare_images_and_analyze(
        self, 
        previous_image_bytes: bytes, 
        current_image_bytes: bytes
    ) -> Dict:
        """
        Compare two images and analyze changes.
        
        Returns structured JSON with:
        - same_tree: bool (are these images of the same tree?)
        - same_time: bool (taken at similar time/angle?)
        - maturity: current maturity level
        - health: current health status
        - soil_moisture: current soil moisture
        - changes: description of changes in Uzbek
        - comment: overall assessment in Uzbek
        """
        base64_previous = base64.b64encode(previous_image_bytes).decode('utf-8')
        base64_current = base64.b64encode(current_image_bytes).decode('utf-8')
        
        prompt = """Ikki rasmni solishtiring va FAQAT JSON formatida javob bering.

Javob formati:
{
  "same_tree": true yoki false,
  "same_time": true yoki false,
  "maturity": "seedling" yoki "young" yoki "mature" yoki "unknown",
  "health": "healthy" yoki "stressed" yoki "critical" yoki "unknown",
  "soil_moisture": "dry" yoki "normal" yoki "wet" yoki "unknown",
  "changes": "O'zgarishlar haqida qisqa matn",
  "comment": "Umumiy holat va tavsiyalar"
}

Tekshirish:
- same_tree: Bir xil daraxt va joymi?
- same_time: Bir xil vaqt va burchakdanmi? (agar bir xil bo'lsa - firibgarlik)
- maturity, health, soil_moisture: IKKINCHI (yangi) rasm uchun
- changes: Birinchi va ikkinchi rasmlar orasidagi farqlar
- comment: Umumiy holat

FAQAT JSON javob bering!"""

        try:
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
                                    "url": f"data:image/jpeg;base64,{base64_previous}",
                                    "detail": "low"
                                }
                            },
                            {
                                "type": "text",
                                "text": "YANGI RASM:"
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_current}"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=1000,
                temperature=0.1
            )
            
            content = response.choices[0].message.content
            
            # Clean response
            content = content.strip()
            if content.startswith("```json"):
                content = content[7:]
            if content.startswith("```"):
                content = content[3:]
            if content.endswith("```"):
                content = content[:-3]
            content = content.strip()
            
            # Parse JSON
            result = json.loads(content)
            
            # Validate required fields
            default_values = {
                "same_tree": True,
                "same_time": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "changes": "O'zgarishlar aniqlanmadi",
                "comment": "Ma'lumot yo'q"
            }
            
            for field, default in default_values.items():
                if field not in result:
                    result[field] = default
            
            return result
        
        except json.JSONDecodeError as e:
            print(f"JSON parse error: {e}, content: {content}")
            return {
                "same_tree": True,
                "same_time": False,
                "maturity": "unknown",
                "health": "unknown",
                "soil_moisture": "unknown",
                "changes": "Tahlil xatosi",
                "comment": "Rasmlarni solishtirishda xatolik"
            }
        except Exception as e:
            print(f"AI compare error: {e}")
            raise
