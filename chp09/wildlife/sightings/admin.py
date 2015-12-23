from django.contrib import admin
from django.contrib.gis.admin import GeoModelAdmin
from models import Country, Animal, Sighting

class SightingAdmin(GeoModelAdmin):
    """
    Web admin behavior for the Sighting model.
    """
    model = Sighting
    list_display = ['date', 'animal', 'rate']
    list_filter = ['date', 'animal', 'rate']
    date_hierarchy = 'date'

class AnimalAdmin(admin.ModelAdmin):
    """
    Web admin behavior for the Animal model.
    """
    model = Animal
    list_display = ['name', 'image_url',]
    
class CountryAdmin(GeoModelAdmin):
    """
    Web admin behavior for the Country model.
    """
    model = Country
    list_display = ['isocode', 'name']
    ordering = ('name',)
    
    class Meta:
        verbose_name_plural = 'countries'

admin.site.register(Animal, AnimalAdmin)
admin.site.register(Sighting, SightingAdmin)
admin.site.register(Country, CountryAdmin)
