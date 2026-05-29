from __future__ import annotations

from abc import ABC, abstractmethod


class VoiceProvider(ABC):
    @abstractmethod
    def generate_speech(self, creature, context: dict) -> str:
        raise NotImplementedError


class RuleBasedVoiceProvider(VoiceProvider):
    def generate_speech(self, creature, context: dict) -> str:
        action = context.get("action", creature.current_action)
        obj = context.get("object_type", "")
        if action == "warn" and obj:
            return f"Small one, no {obj.replace('_', ' ')}."
        if action == "avoid" and obj:
            return f"{creature.name} no like {obj.replace('_', ' ')}."
        if context.get("outcome") == "sick":
            return f"{obj.replace('_', ' ')} hurt belly."
        if action in {"rest_in_nest", "sleep"}:
            return f"Nest warm. {creature.name} stay."
        if action == "play":
            return "Good friend. Play now."
        if action == "investigate_object" and obj == "music_stone":
            return "Stone hum soft."
        if action in {"eat", "seek_food"} and obj:
            return f"{creature.name} try {obj.replace('_', ' ')}."
        if creature.needs.fear > 65:
            return "Too much scare."
        if creature.needs.hunger > 80:
            return "Belly empty."
        return ""
