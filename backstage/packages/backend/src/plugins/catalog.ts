import { CatalogBuilder } from '@backstage/plugin-catalog-backend';
import { ScaffolderEntitiesProcessor } from '@backstage/plugin-catalog-backend-module-scaffolder-entity-model';
import { Router } from 'express';
import { PluginEnvironment } from '../types';
import {CatalogClient} from "@backstage/catalog-client";
import {
    KnativeEventMeshProcessor,
    KnativeEventMeshProvider
} from '@knative-extensions/plugin-knative-event-mesh-backend';

export default async function createPlugin(
  env: PluginEnvironment,
): Promise<Router> {
  const builder = await CatalogBuilder.create(env);
  builder.addProcessor(new ScaffolderEntitiesProcessor());

  builder.addEntityProvider(
      KnativeEventMeshProvider.fromConfig(env.config, {
        logger: env.logger,
        scheduler: env.scheduler,
      }),
  );
  const catalogApi = new CatalogClient({
    discoveryApi: env.discovery,
  });
  const knativeEventMeshProcessor = new KnativeEventMeshProcessor(catalogApi, env.logger);
  builder.addProcessor(knativeEventMeshProcessor);

  const { processingEngine, router } = await builder.build();
  await processingEngine.start();
  return router;
}
