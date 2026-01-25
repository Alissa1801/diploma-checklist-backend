module Api::V1
  class ZonesController < ApplicationController
    # GET /api/v1/zones
    def index
      zones = Zone.all
      render json: zones.as_json(only: [:id, :name, :description])
    end
    
    # GET /api/v1/zones/:id
    def show
      zone = Zone.find(params[:id])
      render json: zone.as_json(include: {
        expected_objects: {},
        expected_conditions: {}
      })
    end
  end
end
