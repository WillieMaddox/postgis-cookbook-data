from django.shortcuts import render_to_response
from django.http import HttpResponse
from vectorformats.Formats import Django, GeoJSON
from models import Animal, Sighting, Country

def home(request):
    """
    Display the home page with the list and a map of the sightings.
    """
    sightings  = Sighting.objects.all()
    return render_to_response("sightings/home.html", {'sightings' : sightings})
    
def get_geojson(request):
    """
    Get geojson (needed by the map) for all of the sightings.
    """
    sightings  = Sighting.objects.all()
    djf = Django.Django(geodjango='geometry', properties=['animal_name', 
        'animal_image_url', 'description', 'rate', 'date_formatted',
        'country_name'])
    geoj = GeoJSON.GeoJSON()
    s = geoj.encode(djf.decode(sightings))
    return HttpResponse(s)

