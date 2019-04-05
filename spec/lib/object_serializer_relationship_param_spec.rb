require 'spec_helper'

describe FastJsonapi::ObjectSerializer do
  include_context 'movie class'

  context "params option" do
    let(:hash) { serializer.serializable_hash }
    let(:serializer) { MovieSerializer.new(movie, params: params) }
    let(:params) { {authorized: true} }

    before(:context) do
      class MovieSerializer
        has_many :agencies do |movie, params|
          movie.actors.map(&:agency) if params[:authorized]
        end

        belongs_to :primary_agency do |movie, params|
          movie.actors.map(&:agency)[0] if params[:authorized]
        end

        belongs_to :secondary_agency, serializer: AgencySerializer do |movie|
          movie.actors.map(&:agency)[1]
        end

        belongs_to :tertiary_agency, record_type: :custom_agency_type do |movie|
          movie.actors.last.agency
        end
      end
    end

    describe "passing params to the serializer" do
      context "with a single record" do
        it "handles relationships that use params" do
          ids = hash[:data][:relationships][:agencies][:data].map{|a| a[:id]}
          ids.map!(&:to_i)
          expect(ids).to eq [0,1,2]
        end

        it "handles relationships that don't use params" do
          expect(hash[:data][:relationships][:secondary_agency][:data]).to include({id: 1.to_s})
        end
      end

      context "with a list of records" do
        let(:movies) { build_movies(3) }
        let(:serializer) { MovieSerializer.new(movies, params: params) }

        it "handles relationship params when passing params to a list of resources" do
          relationships_hashes = hash[:data].map{|a| a[:relationships][:agencies][:data]}.uniq.flatten
          expect(relationships_hashes.map{|a| a[:id].to_i}).to contain_exactly 0,1,2

          uniq_count = hash[:data].map{|a| a[:relationships][:primary_agency] }.uniq.count
          expect(uniq_count).to eq 1
        end

        it "handles relationships without params" do
          uniq_count = hash[:data].map{|a| a[:relationships][:secondary_agency] }.uniq.count
          expect(uniq_count).to eq 1
        end
      end
    end

    describe '#record_type' do
      let(:relationship) { MovieSerializer.relationships_to_serialize[relationship_name] }

      context 'without any options' do
        let(:relationship_name) { :primary_agency }
        it 'infers record_type from relation name' do
          expect(relationship.record_type).to eq :primary_agency
        end
      end

      context 'with serializer option' do
        let(:relationship_name) { :secondary_agency }
        it 'uses type of given serializer' do
          expect(relationship.record_type).to eq :agency
        end
      end

      context 'with record_type option' do
        let(:relationship_name) { :tertiary_agency }
        it 'uses record_type option' do
          expect(relationship.record_type).to eq :custom_agency_type
        end
      end

      context 'with pluralize_type true' do
        let(:relationship_name) { :secondary_agency }

        before(:context) do
          AgencySerializer.pluralize_type true
        end

        after(:context) do
          AgencySerializer.pluralize_type nil
        end

        it 'uses record_type option' do
          expect(relationship.record_type).to eq :agencies
        end
      end
    end
  end
end
