require 'rails_helper'

RSpec.describe 'Projects API (Löschen/Archivieren)', type: :request do
  let(:project) { create(:project) }

  describe 'DELETE /api/v1/projects/:id' do
    it 'requires write access' do
      delete "/api/v1/projects/#{project.id}",
             headers: auth_headers(create(:user, :viewer))

      expect(response).to have_http_status(:forbidden)
      expect(Project.find_by(id: project.id)).to be_present
    end

    it 'permanently deletes the project and cascades to its materials and suppliers' do
      material = create(:material, project: project)
      supplier = create(:supplier, project: project)

      expect do
        delete "/api/v1/projects/#{project.id}", headers: auth_headers
      end.to change(Project, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Material.find_by(id: material.id)).to be_nil
      expect(Supplier.find_by(id: supplier.id)).to be_nil
    end
  end

  describe 'POST /api/v1/projects/:id/archive' do
    it 'soft-removes the project (status archived, data kept)' do
      post "/api/v1/projects/#{project.id}/archive", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('archived')
      expect(project.reload.archived?).to be(true)
    end
  end

  describe 'POST /api/v1/projects/:id/restore' do
    it 'restores an archived project' do
      project.archive!

      post "/api/v1/projects/#{project.id}/restore", headers: auth_headers

      expect(response.parsed_body['status']).to eq('active')
      expect(project.reload.archived?).to be(false)
    end
  end
end
