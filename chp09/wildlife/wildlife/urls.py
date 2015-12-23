from django.conf.urls import patterns, include, url
from django.conf import settings
# recipe 2
from sightings.views import get_geojson, home

from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    url(r'^admin/', include(admin.site.urls)),
    # recipe 2
    (r'^geojson/', get_geojson),
    (r'^$', home),
)

# media files
urlpatterns += patterns('',
    (r'^media/(?P<path>.*)$', 'django.views.static.serve', {
    'document_root': settings.MEDIA_ROOT}))
